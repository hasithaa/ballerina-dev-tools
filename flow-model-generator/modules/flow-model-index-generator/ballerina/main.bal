import ballerina/data.jsondata;
import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/log;

const string PATH_INDEX = "../../flow-model-generator-ls-extension/src/main/resources/";
const string PATH_CONNECTION_JSON = "connections.json";
const string PATH_NODE_TEMPLATE_JSON = "node_templates.json";
const string PATH_SOURCE = "../source/";

type ModuleConfig record {|
    string org;
    string module;
    string icon;
    map<string> sources = {};
    string[] connections = [];
    map<string> connectionsDescriptions = {};
    string[] functions = [];
|};

public function main() returns error? {

    map<ModuleConfig> modules = check fetchData();
    log:printInfo("Fetched modules ", modules = modules.keys());

    IndexConnections connections = {items: []};
    IndexNodeTemplateMap nodeTemplates = {};
    foreach var config in modules {
        check generateNodeTemplates(config, nodeTemplates);
    }

    foreach DataConnectionGroup groups in connectionBuilder.groups {

        IndexCategory indexCategory = {
            metadata: {label: groups.label},
            items: <IndexCategory[]>[]
        };
        connections.items.push(indexCategory);
        foreach DataConnection connection in groups.items {

            ModuleConfig config = modules.get(connection.ref[0] + "/" + connection.ref[1]);

            string connectionsDescriptions = config.connectionsDescriptions.get(connection.ref[2]);

            IndexCategory indexSubCategory = {
                metadata: {label: connection.label, description: connectionsDescriptions, icon: config.icon},
                items: <IndexNode[]>[]
            };
            indexCategory.items.push(indexSubCategory);
            string keyPrefix = string `${connection.ref[0]}:${connection.ref[1]}:${connection.ref[2]}`;
            string[] clientNodesNames = nodeTemplates.keys().filter(k => k.includes(keyPrefix));
            foreach string key in clientNodesNames {
                IndexNodeTemplate template = nodeTemplates.get(key);
                IndexNode node = {
                    metadata: template.metadata,
                    codedata: template.codedata,
                    enabled: true
                };
                indexSubCategory.items.push(node);
            }
        }
    }
    check io:fileWriteJson(PATH_INDEX + PATH_NODE_TEMPLATE_JSON, nodeTemplates);
    check io:fileWriteJson(PATH_INDEX + PATH_CONNECTION_JSON, connections);
}

function generateNodeTemplates(ModuleConfig config, IndexNodeTemplateMap nodeTemplates) returns error? {
    if config.connections.length() == 0 {
        return;
    }
    ClientItem[] clData = check jsondata:parseStream(check io:fileReadBlocksAsStream(config.sources.get("clients")));
    foreach string cl in config.connections {
        ClientItem? connection = ();
        foreach ClientItem data in clData {
            if data.name == cl {
                connection = data;
                break;
            }
        }
        if connection == () {
            log:printError("Client not found: " + cl, config = config);
            continue;
        }
        config.connectionsDescriptions[cl] = connection.description;

        // handle Init method
        IndexNodeTemplate initTemplate = handleInitMethod([config.org, config.module, cl], connection);
        nodeTemplates[string `NEW_CONNECTION:${config.org}:${config.module}:${cl}:init`] = initTemplate;
        initTemplate.metadata.icon = config.icon;

        IndexNodeTemplate[] templates = handleRemoteMethods([config.org, config.module, cl], connection);
        foreach IndexNodeTemplate template in templates {
            nodeTemplates[string `ACTION_CALL:${config.org}:${config.module}:${cl}:${template.codedata.symbol}`] = template;
            template.metadata.icon = config.icon;
        }
    }
}

function fetchData() returns map<ModuleConfig>|error {

    // TODO: Use the correct client. Using http since NO SDL client is available.
    http:Client gqlCL = check new ("https://api.central.ballerina.io/2.0/graphql");

    map<string> orgs = {}; // Unique orgs.
    map<ModuleConfig> modules = {}; // Unique modules.

    // Build a list of modules to fetch, from the ref in the groups.
    foreach DataConnectionGroup groups in connectionBuilder.groups {
        foreach DataConnection connection in groups.items {
            orgs[connection.ref[0]] = connection.ref[0];
            ModuleConfig config;
            if modules.hasKey(connection.ref[0] + "/" + connection.ref[1]) {
                config = modules.get(connection.ref[0] + "/" + connection.ref[1]);
            } else {
                config = {org: connection.ref[0], module: connection.ref[1], icon: ""};
            }
            config.connections.push(connection.ref[2]);
            modules[connection.ref[0] + "/" + connection.ref[1]] = config;
        }
    }

    // Fetch the modules.
    foreach var org in orgs {
        string orgFile = PATH_SOURCE + org + ".json";
        GQLPackagesResponse res;
        if !check file:test(orgFile, file:EXISTS) {
            res = check jsondata:parseStream(check io:fileReadBlocksAsStream(orgFile));
        } else {
            json request = {"operationName": null, "variables": {}, "query": "{\n  query: packages(orgName: \"" + org + "\", limit: 1000) {\n    packages {\n      organization\n      name\n      version\n      icon\n      keywords\n      modules {\n        name\n      }\n    }\n  }\n}\n"};
            res = check gqlCL->post("", request);
            check io:fileWriteJson(orgFile, res.toJson());
        }

        foreach PackagesItem pkg in res.data.query.packages {
            foreach ModulesItem module in pkg.modules {
                final string key = pkg.organization + "/" + module.name;
                if !modules.hasKey(key) {
                    continue;
                }
                ModuleConfig config = modules.get(key);

                string moduleFile = PATH_SOURCE + key + ".json";
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

function handleInitMethod([string, string, string] ref, ClientItem connection) returns IndexNodeTemplate {

    IndexNodeTemplate initTemplate = {
        metadata: {label: "New Connection", description: "Create a new connection"},
        codedata: {node: "NEW_CONNECTION", module: ref[1], symbol: "init", org: ref[0], 'object: ref[2]},
        properties: {},
        flags: 0
    };
    string prefix = ref[1];
    if ref[1].includes(".") {
        prefix = ref[1].substring(<int>ref[1].lastIndexOf(".") + 1);
    }
    initTemplate.codedata["importStmt"] = "import " + ref[0] + "/" + ref[1] + " as " + prefix;

    map<IndexProperty> properties = {};
    initTemplate.properties = properties;
    properties["scope"] = {
        metadata: {label: "Connection Scope", description: "Scope of the connection, Global or Local"},
        valueType: "Enum",
        value: "Global",
        optional: false,
        editable: false,
        valueTypeConstraints: {'enum: ["Global", "Local"]},
        'order: 0
    };
    properties["variable"] = {
        metadata: {label: "Variable", description: "Variable to store the connection"},
        valueType: "Identifier",
        value: "connection",
        optional: false,
        editable: true,
        'order: 1,
        valueTypeConstraints: {identifier: {isExistingVariable: false, isNewVariable: true}}
    };
    properties["type"] = {
        metadata: {label: "Type", description: "Type of the connection"},
        value: prefix + ":" + ref[2],
        valueType: "Type",
        optional: false,
        editable: false,
        valueTypeConstraints: {'type: {"value": prefix + ":" + ref[2]}},
        'order: 2
    };

    // Find init method.
    MethodsItem? init = connection.initMethod;
    if init is () {
        // Check for method parameters
        MethodsItem[] methods = connection.methods;
        if methods.length() == 0 || methods.filter(m => m.name == "init").length() == 0 {
            // No explicit init method found
        } else {
            init = methods.filter(m => m.name == "init")[0];
        }
    }
    if init !is () {
        // Add method parameters as properties
        handleMethodParameters(init, properties, false);
    }

    // TODO: Check init contains errors. Use category field. Following is a temporary fix. 
    setCheckedFlag(initTemplate);
    return initTemplate;
}

function handleRemoteMethods([string, string, string] ref, ClientItem connection) returns IndexNodeTemplate[] {
    IndexNodeTemplate[] templates = [];
    RemoteMethodsItem[] methods = connection.remoteMethods;
    foreach RemoteMethodsItem method in methods {
        IndexNodeTemplate template = {
            metadata: {label: method.name, description: method.description},
            codedata: {node: "ACTION_CALL", module: ref[1], symbol: method.name, org: ref[0], 'object: ref[2]},
            properties: {},
            flags: 0
        };
        string prefix = ref[1];
        if ref[1].includes(".") {
            prefix = ref[1].substring(<int>ref[1].lastIndexOf(".") + 1);
        }
        template.codedata["importStmt"] = "import " + ref[0] + "/" + ref[1] + " as " + prefix;

        map<IndexProperty> properties = {};
        template.properties = properties;
        properties["connection"] = {
            metadata: {label: "Connection", description: "Connection to use"},
            valueType: "Identifier",
            value: "connection",
            optional: false,
            editable: true,
            'order: 0,
            valueTypeConstraints: {'type: {typeOf: prefix + ":" + ref[2]}, identifier: {isExistingVariable: true, isNewVariable: false}}
        };

        properties["variable"] = {
            metadata: {label: "Variable", description: "Variable to store the connection"},
            valueType: "Identifier",
            value: "res",
            optional: false,
            editable: true,
            'order: 1,
            valueTypeConstraints: {identifier: {isExistingVariable: false, isNewVariable: true}}
        };
        // We fix this later when we have the return type of the remote method
        properties["type"] = {
            metadata: {label: "Type", description: "Type of the result"},
            value: "", // Fixed with return type
            valueType: "Type",
            optional: false,
            editable: false,
            'order: 2
        };
        handleRemoteMethodParameters(method, properties);

        // TODO: Check init contains errors. Use category field. Following is a temporary fix. 
        setCheckedFlag(template);
        templates.push(template);
    }
    return templates;
}

function setCheckedFlag(IndexNodeTemplate template) {
    template.flags = template.flags | 1;
    if template.codedata.hasKey("flags") {
        template.codedata["flags"] = <int>template.codedata["flags"] | 1;
    } else {
        template.codedata["flags"] = 1;
    }
}

function handleMethodParameters(MethodsItem method, map<IndexProperty> properties, boolean handleReturn = true) {
    Type? dependentlyTyped = ();
    foreach ParametersItem item in method.parameters {
        if handleReturn && item.defaultValue == "<>" {
            // This is dependently Typed function
            dependentlyTyped = item.'type;
        }
        properties[item.name] = {
            metadata: {label: item.name, description: item.description},
            valueType: "Expression",
            value: item.defaultValue,
            optional: item.defaultValue != "" && item.defaultValue != "<>",
            editable: true,
            valueTypeConstraints: {'type: item.'type.toJson()},
            'order: properties.length()
        };
    }
    // TODO: Handle return type
}

function handleRemoteMethodParameters(RemoteMethodsItem method, map<IndexProperty> properties, boolean handleReturn = true) {
    Type? dependentlyTyped = ();
    foreach ParametersItem item in method.parameters {
        if handleReturn && item.defaultValue == "<>" {
            // This is dependently Typed function
            dependentlyTyped = item.'type;
        }
        properties[item.name] = {
            metadata: {label: item.name, description: item.description},
            valueType: "Expression",
            value: item.defaultValue,
            optional: item.defaultValue != "" && item.defaultValue != "<>",
            editable: true,
            valueTypeConstraints: {'type: item.'type.toJson()},
            'order: properties.length()
        };
    }
    if method.returnParameters.length() > 0 {
        // TODO: Improve. We fix this later. Assume dependently typed allways used if present.
        // Also we assume checked is always present, so we ignore errors.
        IndexProperty typeProperty = <IndexProperty>properties["type"];

        ReturnParametersItem returnParametersItem = method.returnParameters[0];
        if dependentlyTyped !is () {
            if dependentlyTyped.category == "types" {
                // This is refering to a Type definition (80% case) and we need to get the type from semantic model.
                // As a temporary fix we assume the type is a json object..
                typeProperty.value = "map<json>"; // Ideally we need a built in type called JSON objects. 
            } else {
                typeProperty.value = dependentlyTyped.name ?: "";
            }
        } else {
            // Improve this logic for union and others. 
            if returnParametersItem.'type.memberTypes.length() > 0 {
                // This is a union type. Get the first non-error type for now. 
                // TODO: Improve this logic
                foreach var item in returnParametersItem.'type.memberTypes {
                    if item.category != "errors" {
                        typeProperty.value = item.name ?: "";
                        break;
                    }
                }
            } else {
                typeProperty.value = returnParametersItem.'type.name ?: "";
            }
            typeProperty.valueTypeConstraints = {'type: returnParametersItem.'type.toJson()};
        }
    }
}
