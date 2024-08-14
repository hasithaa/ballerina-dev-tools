import ballerina/data.jsondata;
import ballerina/file;
import ballerina/http;
import ballerina/io;

enum DataType {
    CLIENTS = "clients",
    FUNCTIONS = "functions"
}

function loadCachedData(ModuleConfig moduleConfig, string key, DataType dataType) returns ClientItem|FunctionItem|error? {

    json dataSource;
    typedesc<ClientItem|FunctionItem> expectedType;
    if CLIENTS == dataType {
        dataSource = moduleConfig.cachedDataJson.get(CLIENTS);
        expectedType = ClientItem;
    } else {
        dataSource = moduleConfig.cachedDataJson.get(FUNCTIONS);
        expectedType = FunctionItem;
    }

    if dataSource !is json[] {
        return error("Invalid cached data, expected an array of " + expectedType.toString());
    }
    foreach var item in dataSource {
        string? name = check item.name;
        if name == key {
            return check jsondata:parseAsType(item, {}, expectedType);
        }
    }
    return;
}

function fetchDataFromRemoteAPI() returns map<ModuleConfig>|error {

    // TODO: Use the correct client. Using http since no grapql-SDL client is available.
    http:Client gqlCL = check new ("https://api.central.ballerina.io/2.0/graphql");

    final map<ModuleConfig> modules = {}; // Unique modules.
    final map<string> orgs = {}; // Unique orgs.

    readPrebBuiltDataAndBuildCache(modules, orgs);

    // Fetch the modules.
    foreach var org in orgs {
        string orgFile = getCachedDataFilePath(org);
        GQLPackagesResponse res;
        if check file:test(orgFile, file:EXISTS) {
            res = check jsondata:parseStream(check io:fileReadBlocksAsStream(orgFile));
        } else {
            json request = {operationName: null, variables: {}, query: string `{  query: packages(orgName: "${org}", limit: 1000) { packages { organization name version icon keywords modules { name } } }}`};
            res = check gqlCL->post("", request);
            check io:fileWriteJson(orgFile, res.toJson());
        }

        foreach PackagesItem pkg in res.data.query.packages {
            foreach ModulesItem module in pkg.modules {
                final string key = getModuleQName(pkg.organization, module.name);
                if !modules.hasKey(key) {
                    continue;
                }
                ModuleConfig config = modules.get(key);

                string moduleFile = getCachedDataFilePath(key);
                GQLDocsResponse docRes;
                if check file:test(moduleFile, file:EXISTS) {
                    docRes = check jsondata:parseStream(check io:fileReadBlocksAsStream(moduleFile));
                } else {
                    json docRequest = {
                        "operationName": null,
                        "variables": {},
                        "query": "{\n  query: apiDocs(inputFilter: {moduleInfo: {orgName: \"" + pkg.organization + "\", moduleName: \"" + module.name + "\", version: \"" + pkg.version + "\"}}) {\n    docsData {\n      modules {\n        clients\n        listeners\n        functions\n      }\n    }\n  }\n}\n"
                    };
                    docRes = check gqlCL->post("", docRequest);
                }
                config.icon = pkg.icon;
                check io:fileWriteJson(PATH_SOURCE + key + ".json", docRes.toJson());
                foreach var [itemKey, item] in docRes.data.query.docsData.modules[0].entries() {
                    if item !is string {
                        continue;
                    }
                    json data = <json>check jsondata:parseString(item);
                    config.cachedDataJson[itemKey] = data;
                }
            }
        }
    }
    return modules;
}

function readPrebBuiltDataAndBuildCache(map<ModuleConfig> modules, map<string> orgs) {
    // Build a list of modules to fetch, from the ref in the groups.
    foreach DataGroup[] val in prebuiltDataSet {
        var groups = <DataGroup[]>val; // JBug: Union of the same type is not iterable.
        foreach DataGroup group in groups {
            foreach DataItem data in group.items {
                if data.enabled == false {
                    continue;
                }
                final var [orgName, moduleName, _] = data.ref;
                final string moduleQName = getModuleQName(orgName, moduleName);

                ModuleConfig config;
                if modules.hasKey(moduleQName) {
                    config = modules.get(moduleQName);
                } else {
                    config = {orgName, moduleName};
                }
                modules[moduleQName] = config;
                orgs[orgName] = orgName;
            }
        }
    }
}

function getModuleQName(string org, string module) returns string {
    return org + "/" + module;
}

function getCachedDataFilePath(string cache) returns string {
    return string `${PATH_SOURCE}${cache}.json`;
}
