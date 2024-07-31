final DataSet prebuiltDataSet = {
    connections: [
        {
            label: "Network",
            items: [
                {
                    label: "HTTP Connection",
                    ref: ["ballerina", "http", "Client"],
                    popular: ["GET, POST, PUT, PATHCH, DELETE"]
                },
                {
                    label: "GraphQL Connection",
                    ref: ["ballerina", "graphql", "Client"]
                },
                {
                    label: "gRPC Connection",
                    ref: ["ballerina", "grpc", "Client"]
                },
                {
                    label: "gRPC Streaming Connection",
                    ref: ["ballerina", "grpc", "StreamingClient"]
                },
                {
                    label: "WebSocket Connection",
                    ref: ["ballerina", "websocket", "Client"]
                }
            ]
        },
        {
            label: "Databases",
            items: [
                {
                    label: "MySQL",
                    ref: ["ballerinax", "mysql", "Client"]
                },
                {
                    label: "Redis",
                    ref: ["ballerinax", "redis", "Client"],
                    popular: ["get, set, del, append"]
                },
                {
                    label: "MS SQL",
                    ref: ["ballerinax", "mssql", "Client"]
                },
                {
                    label: "Oracle",
                    ref: ["ballerinax", "oracledb", "Client"]
                },
                {
                    label: "MongoDB",
                    ref: ["ballerinax", "mongodb", "Client"]
                },
                {
                    label: "PostgreSQL",
                    ref: ["ballerinax", "postgresql", "Client"]
                }
            ]
        }
    ],
    functions: [
        {
            label: "Logging",
            items: [
                {
                    label: "Log Info",
                    ref: ["ballerina", "log", "printInfo"]
                },
                {
                    label: "Log Error",
                    ref: ["ballerina", "log", "printError"]
                },
                {
                    label: "Log Warn",
                    ref: ["ballerina", "log", "printWarn"]
                },
                {
                    label: "Log Debug",
                    ref: ["ballerina", "log", "printDebug"]
                }
            ]
        },
        {
            label: "Data Conversion",
            items: [
                {
                    label: "Schema To JSON",
                    ref: ["ballerina", "data.jsondata", "toJson"]
                },
                {
                    label: "Schema To XML",
                    ref: ["ballerina", "data.xmldata", "toXml"]
                },
                {
                    label: "JSON To Schema",
                    ref: ["ballerina", "data.jsondata", "parseAsType"]
                },
                {
                    label: "XML To Schema",
                    ref: ["ballerina", "data.xmldata", "parseAsType"]
                }
            ]
        },
        {
            label: "JSON",
            items: [
                {
                    label: "Evaluate JSON Path",
                    ref: ["ballerina", "data.jsondata", "read"]
                },
                {
                    label: "JSON Pretty Print",
                    ref: ["ballerina", "data.jsondata", "prettify"]
                }
            ]
        },
        {
            label: "XML",
            items: [
                {
                    label: "XSLT Transform",
                    ref: ["ballerina", "xslt", "transform"]
                }
            ]
        },
        {
            label: "File Data",
            items: [
                {
                    label: "Read CSV",
                    ref: ["ballerina", "io", "fileReadCsv"]
                },
                {
                    label: "Read JSON",
                    ref: ["ballerina", "io", "fileReadJson"]
                },
                {
                    label: "Read Bytes",
                    ref: ["ballerina", "io", "fileReadBytes"]
                },
                {
                    label: "Read XML",
                    ref: ["ballerina", "io", "fileReadXml"]
                },
                {
                    label: "Write CSV",
                    ref: ["ballerina", "io", "fileWriteCsv"]
                },
                {
                    label: "Write JSON",
                    ref: ["ballerina", "io", "fileWriteJson"]
                },
                {
                    label: "Write Bytes",
                    ref: ["ballerina", "io", "fileWriteBytes"]
                },
                {
                    label: "Write XML",
                    ref: ["ballerina", "io", "fileWriteXml"]
                }
            ]
        }
    ]
};

type DataItem record {|
    string label;
    [string, string, string] ref;
    string[] popular?; // TODO: implement this.
    boolean enabled?;
|};

type DataGroup record {|
    string label;
    DataItem[] items;
|};

type DataSet record {|
    DataGroup[] connections;
    DataGroup[] functions;
|};