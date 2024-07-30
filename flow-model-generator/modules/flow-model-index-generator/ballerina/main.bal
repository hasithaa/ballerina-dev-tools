import ballerina/data.jsondata;
import ballerina/http;
import ballerina/io;

const string PATH_INDEX = "../index/";
const string PATH_CONNECTION_JSON = "connections.json";
const string PATH_NODE_TEMPLATE_JSON = "node_templates.json";
const string PATH_SOURCE = "../source/";

// TODO: Use the correct client. Using http since NO SDL client is available.
http:Client gqlCL = check new ("https://api.central.ballerina.io/2.0/graphql");

public function main() returns error? {

    map<string[]> modules = check fetchData();
}

function fetchData() returns map<string[]>|error {

    map<string> orgs = {}; // Unique orgs.
    map<string[]> modules = {}; // Unique modules.

    // Build a list of modules to fetch, from the ref in the groups.
    foreach DataConnectionGroup groups in connectionBuilder.groups {
        foreach DataConnection connection in groups.items {
            orgs[connection.ref[0]] = connection.ref[0];
            modules[connection.ref[0] + "_" + connection.ref[1]] = [];
        }
    }

    // Fetch the modules.
    foreach var org in orgs {
        json request = {"operationName": null, "variables": {}, "query": "{\n  query: packages(orgName: \"" + org + "\", limit: 1000) {\n    packages {\n      organization\n      name\n      version\n      icon\n      keywords\n      modules {\n        name\n      }\n    }\n  }\n}\n"};

        GQLPackagesResponse res = check gqlCL->post("", request);
        check io:fileWriteJson(PATH_SOURCE + org + ".json", res.toJson());

        foreach PackagesItem pkg in res.data.query.packages {
            foreach ModulesItem module in pkg.modules {
                final string key = pkg.organization + "_" + module.name;
                if !modules.hasKey(key) {
                    continue;
                }

                json docRequest = {
                    "operationName": null,
                    "variables": {},
                    "query": "{\n  query: apiDocs(inputFilter: {moduleInfo: {orgName: \"" + pkg.organization + "\", moduleName: \"" + module.name + "\", version: \"" + pkg.version + "\"}}) {\n    docsData {\n      modules {\n        clients\n        listeners\n        functions\n      }\n    }\n  }\n}\n"
                };
                GQLDocsResponse docRes = check gqlCL->post("", docRequest);
                check io:fileWriteJson(PATH_SOURCE + key + ".json", docRes.toJson());
                foreach var [itemKey, item] in docRes.data.query.docsData.modules[0].entries() {
                    if item !is string {
                        continue;
                    }
                    final string file = PATH_SOURCE + key + "_" + itemKey + ".json";
                    modules.get(key).push(file);
                    check io:fileWriteJson(file, <json> check jsondata:parseString(item));
                }
            }
        }
    }
    return modules;
}
