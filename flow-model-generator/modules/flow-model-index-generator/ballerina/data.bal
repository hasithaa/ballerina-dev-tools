final DataConnections connectionBuilder = {
    groups: [
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
                // {
                //     label: "Oracle",
                //     ref: ["ballerinax", "oracle", "Client"]
                // },
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
    ]
};
