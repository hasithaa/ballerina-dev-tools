import ballerina/data.jsondata;
import ballerina/file;
import ballerina/http;
import ballerina/io;

function fetchDataFromRemoteAPI() returns map<ModuleConfig>|error {

    // TODO: Use the correct client. Using http since no grapql-SDL client is available.
    http:Client gqlCL = check new ("https://api.central.ballerina.io/2.0/graphql");

    map<ModuleConfig> modules = {}; // Unique modules.
    map<string> orgs = {}; // Unique orgs.

    readPrebuiltDataAndBuildCache(modules, orgs);

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
                    final string file = PATH_SOURCE + key + "_" + itemKey + ".json";
                    config.sources[itemKey] = file;
                    check io:fileWriteJson(file, <json>check jsondata:parseString(item));
                }
            }
        }
    }
    return modules;
}

function readPrebuiltDataAndBuildCache(map<ModuleConfig> modules, map<string> orgs) {
    // Build a list of modules to fetch, from the ref in the groups.
    foreach [string, DataGroup[]] [key, val] in prebuiltDataSet.entries() {
        var groups = <DataGroup[]>val; // JBug: Union of the same type is not iterable.
        foreach DataGroup group in groups {
            foreach DataItem data in group.items {
                if data.enabled == false {
                    continue;
                }
                final var [orgName, moduleName, symbolOrClientName] = data.ref;
                final string moduleQName = getModuleQName(orgName, moduleName);

                ModuleConfig config;
                if modules.hasKey(moduleQName) {
                    config = modules.get(moduleQName);
                } else {
                    config = {orgName, moduleName};
                }
                if key == "connections" {
                    config.connections.push(symbolOrClientName);
                } else {
                    config.functions.push(symbolOrClientName);
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
