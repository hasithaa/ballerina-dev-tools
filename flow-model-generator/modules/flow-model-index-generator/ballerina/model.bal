type DataConnection record {
    string label;
    [string, string, string] ref;
    string[] popular?;
};

type DataConnectionGroup record {
    string label;
    DataConnection[] items;
};

type DataConnections record {
    DataConnectionGroup[] groups;
};

type IndexKeyword record {|
    string org;
    string module;
    string version;
    string?[] ids;
    string icon?;
|};

type IndexMetadata record {|
    string label;
    string description?;
    string[] keywords?;
    json...;
|};

type IndexCodedata record {|
    string node;
    string module;
    string symbol;
    string org;
    string 'object?;
    json...;
|};

type IndexNode record {|
    IndexMetadata metadata;
    IndexCodedata codedata;
    boolean enabled?;
|};

type IndexCategory record {|
    IndexMetadata metadata;
    IndexNode[]|IndexCategory[] items;
|};

type IndexConnections record {|
    IndexCategory[] items;
|};

type IndexProperty record {|
    IndexMetadata metadata;
    string valueType;
    string value;
    boolean optional;
    boolean editable;
    json valueTypeConstraints?;
    int 'order;
|};

type IndexNodeTemplate record {|
    IndexMetadata metadata;
    IndexCodedata codedata;
    map<IndexProperty> properties;
    int flags;
|};

type IndexNodeTemplateMap map<IndexNodeTemplate>;