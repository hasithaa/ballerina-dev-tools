import ballerina/io;
import ballerina/log;

const string PATH_INDEX = "../../flow-model-generator-ls-extension/src/main/resources/";
const string PATH_CONNECTION_JSON = "connections.json";
const string PATH_CONNECTOR_JSON = "connector.json";
const string PATH_FUNCTION_JSON = "functions.json";
const string PATH_NODE_TEMPLATE_JSON = "node_templates.json";
const string PATH_SOURCE = "../source/";

type ModuleConfig record {|
    string orgName;
    string moduleName;
    string icon = "";
    map<json> cachedDataJson = {};
|};

type ModuleConfigMap map<ModuleConfig>;

type Index record {|
    IndexAvilableNodes clients = {items: []};
    IndexConnectionNodes connections = {};
    IndexAvilableNodes functions = {items: []};
    IndexNodeTemplateMap nodeTemplates = {};
|};

public function main() returns error? {

    ModuleConfigMap moduleConfigs = check fetchDataFromRemoteAPI();

    Index index = {};
    check buildIndex(moduleConfigs, index, CLIENTS);
    check buildIndex(moduleConfigs, index, FUNCTIONS);

    check io:fileWriteJson(PATH_INDEX + PATH_NODE_TEMPLATE_JSON, index.nodeTemplates);
    check io:fileWriteJson(PATH_INDEX + PATH_CONNECTOR_JSON, index.clients);
    check io:fileWriteJson(PATH_INDEX + PATH_CONNECTION_JSON, index.connections);
    check io:fileWriteJson(PATH_INDEX + PATH_FUNCTION_JSON, index.functions);
}

function getDataGroup(DataType 'type) returns DataGroup[] {
    return 'type == CLIENTS ? prebuiltDataSet.connections : prebuiltDataSet.functions;
}

function buildIndex(ModuleConfigMap modulesConfigMap, Index index, DataType dataGroupType) returns error? {

    foreach DataGroup dataGroup in getDataGroup(dataGroupType) {
        final IndexCategory indexCategory = {
            metadata: {label: dataGroup.label},
            items: <IndexNode[]>[]
        };
        if dataGroupType == CLIENTS {
            index.clients.items.push(indexCategory);
        } else {
            index.functions.items.push(indexCategory);
        }

        foreach DataItem dataItemConnection in dataGroup.items {
            if dataGroupType == CLIENTS {
                check buildConnectorIndexForDataItem(modulesConfigMap, index, indexCategory, dataItemConnection);
            } else {
                check buildFunctionIndexForDataItem(modulesConfigMap, index, indexCategory, dataItemConnection);
            }
        }
    }
}

// Build Connector Index. Can be refactor futher.

function buildConnectorIndexForDataItem(ModuleConfigMap modulesConfigMap, Index index, IndexCategory indexCategory, DataItem dataItemConnection) returns error? {

    final var [orgName, moduleName, clientName] = dataItemConnection.ref;

    final ModuleConfig moduleConfig = modulesConfigMap.get(getModuleQName(orgName, moduleName));
    final ClientItem? clientItem = <ClientItem?>check loadCachedData(moduleConfig, clientName, CLIENTS);

    if clientItem == () {
        log:printWarn("Client data not found for module: ", mod = moduleName, cl = clientItem);
        return ();
    }

    final string connectionsDescriptions = clientItem.description;

    // handle Init method
    final IndexNodeTemplate initTemplate = handleInitMethod(dataItemConnection.ref, clientItem);
    final string connectorKey = string `NEW_CONNECTION:${orgName}:${moduleName}:${clientName}:init`;
    index.nodeTemplates[connectorKey] = initTemplate;
    initTemplate.metadata.icon = moduleConfig.icon;

    final IndexNode connectorNode = {
        metadata: {label: dataItemConnection.label, description: connectionsDescriptions, icon: moduleConfig.icon},
        codedata: initTemplate.codedata,
        enabled: true
    };
    indexCategory.items.push(connectorNode);

    // Handle Connection Actions
    final IndexNode[] actionNodes = [];
    index.connections[connectorKey] = actionNodes;

    final IndexNodeTemplate[] templates = handleRemoteMethods(dataItemConnection.ref, clientItem);
    foreach IndexNodeTemplate template in templates {
        actionNodes.push({
            metadata: template.metadata,
            codedata: template.codedata,
            enabled: true
        });
        index.nodeTemplates[string `ACTION_CALL:${orgName}:${moduleName}:${clientName}:${template.codedata.symbol}`] = template;
        template.metadata.icon = moduleConfig.icon;
    }

    // TODO sort the actions based on the popularity and name.
}

function buildFunctionIndexForDataItem(ModuleConfigMap modulesConfigMap, Index index, IndexCategory indexCategory, DataItem dataItemConnection) returns error? {

    final var [orgName, moduleName, functionName] = dataItemConnection.ref;

    final ModuleConfig moduleConfig = modulesConfigMap.get(getModuleQName(orgName, moduleName));
    final FunctionItem? functionItem = <FunctionItem?>check loadCachedData(moduleConfig, functionName, FUNCTIONS);

    if functionItem == () {
        log:printWarn("Function data not found for module: ", mod = moduleName, cl = functionItem);
        return ();
    }

    final string connectionsDescriptions = functionItem.description;

    IndexNodeTemplate template = handleFunction([orgName, moduleName, functionName], functionItem);
    index.nodeTemplates[string `FUNCTION_CALL:${orgName}:${moduleName}:${functionName}`] = template;
    template.metadata.icon = moduleConfig.icon;

    final IndexNode connectorNode = {
        metadata: {label: dataItemConnection.label, description: connectionsDescriptions, icon: moduleConfig.icon},
        codedata: template.codedata,
        enabled: true
    };
    indexCategory.items.push(connectorNode);
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
    FunctionItem? init = connection.initMethod;
    if init is () {
        // Check for method parameters
        FunctionItem[] methods = connection.methods;
        if methods.length() == 0 || methods.filter(m => m.name == "init").length() == 0 {
            // No explicit init method found
        } else {
            init = methods.filter(m => m.name == "init")[0];
        }
    }
    if init !is () {
        // Add method parameters as properties
        handleFunctionParameters(init, properties, false);
    }

    // TODO: Check init contains errors. Use category field. Following is a temporary fix. 
    setCheckedFlag(initTemplate);
    return initTemplate;
}

// LS: Bug rename following method.
function handleRemoteMethods([string, string, string] ref, ClientItem connection) returns IndexNodeTemplate[] {
    IndexNodeTemplate[] templates = [];
    FunctionItem[] methods = connection.remoteMethods;
    foreach FunctionItem method in methods {
        IndexNodeTemplate template = {
            metadata: {label: <string>method.name, description: method.description},
            codedata: {node: "ACTION_CALL", module: ref[1], symbol: <string>method.name, org: ref[0], 'object: ref[2]},
            properties: {},
            flags: 0
        };
        string prefix = ref[1];
        if ref[1].includes(".") {
            prefix = ref[1].substring(<int>ref[1].lastIndexOf(".") + 1);
        }
        template.codedata["importStmt"] = "import " + ref[0] + "/" + ref[1] + " as " + prefix;

        template.properties["connection"] = {
            metadata: {label: "Connection", description: "Connection to use"},
            valueType: "Identifier",
            value: "connection",
            optional: false,
            editable: true,
            'order: template.properties.length(),
            valueTypeConstraints: {'type: {typeOf: prefix + ":" + ref[2]}, identifier: {isExistingVariable: true, isNewVariable: false}}
        };

        template.properties["variable"] = {
            metadata: {label: "Variable", description: "Variable to store the connection"},
            valueType: "Identifier",
            value: "res",
            optional: false,
            editable: true,
            'order: template.properties.length(),
            valueTypeConstraints: {identifier: {isExistingVariable: false, isNewVariable: true}}
        };
        // We fix this later when we have the return type of the remote method
        template.properties["type"] = {
            metadata: {label: "Type", description: "Type of the result"},
            value: "", // Fixed with return type
            valueType: "Type",
            optional: false,
            editable: false,
            'order: template.properties.length()
        };
        handleFunctionParameters(method, template.properties);

        // TODO: Check init contains errors. Use category field. Following is a temporary fix. 
        setCheckedFlag(template);
        templates.push(template);
    }
    return templates;
}

function handleFunction([string, string, string] ref, FunctionItem func) returns IndexNodeTemplate {
    IndexNodeTemplate template = {
        metadata: {label: <string>func.name, description: func.description},
        codedata: {node: "FUNCTION_CALL", module: ref[1], symbol: <string>func.name, org: ref[0]},
        properties: {},
        flags: 0
    };
    string prefix = ref[1];
    if ref[1].includes(".") {
        prefix = ref[1].substring(<int>ref[1].lastIndexOf(".") + 1);
    }
    template.codedata["importStmt"] = "import " + ref[0] + "/" + ref[1] + " as " + prefix;

    template.properties["variable"] = {
        metadata: {label: "Variable", description: "Variable to store the connection"},
        valueType: "Identifier",
        value: "res",
        optional: false,
        editable: true,
        'order: template.properties.length(),
        valueTypeConstraints: {identifier: {isExistingVariable: false, isNewVariable: true}}
    };
    // We fix this later when we have the return type of the remote method
    template.properties["type"] = {
        metadata: {label: "Type", description: "Type of the result"},
        value: "", // Fixed with return type
        valueType: "Type",
        optional: false,
        editable: false,
        'order: template.properties.length()
    };
    handleFunctionParameters(func, template.properties);

    // TODO: Check init contains errors. Use category field. Following is a temporary fix. 
    setCheckedFlag(template);
    return template;
}

function setCheckedFlag(IndexNodeTemplate template) {
    template.flags = template.flags | 1;
    if template.codedata.hasKey("flags") {
        template.codedata["flags"] = <int>template.codedata["flags"] | 1;
    } else {
        template.codedata["flags"] = 1;
    }
}

function handleFunctionParameters(FunctionItem method, map<IndexProperty> properties, boolean handleReturn = true) {
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
