import ballerina/data.jsondata;

function loadCachedClientData(ModuleConfig moduleConfig, string clientName) returns ClientItem|error? {
    ClientItem[]? clientItems = moduleConfig.tempResult.clientItems;
    if clientItems == () {
        clientItems = check jsondata:parseAsType(moduleConfig.cachedDataJson.get("clients"));
        moduleConfig.tempResult.clientItems = clientItems;
    }
    foreach var clientItem in clientItems ?: [] {
        // Search for the client
        if clientItem.name == clientName {
            return clientItem;
        }
    }
}

function cleanCachedClientData(ModuleConfigMap modulesConfigMap) {
    foreach var moduleConfig in modulesConfigMap {
        if moduleConfig.tempResult.clientItems != () {
            moduleConfig.tempResult.clientItems = ();
        }
    }
}
