type DataItem record {
    string label;
    [string, string, string] ref;
    string[] popular?; // TODO: implement this.
    boolean enabled?;
};

type DataGroups record {
    string label;
    DataItem[] items;
};

type DataSet record {
    DataGroups[] groups;
};

type IndexMetadata record {|
    string label;
    string description?;
    string[] keywords?;
    string icon?;
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

type IndexAvilableNodes record {|
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