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

type IndexConnectionNodes record {|
    IndexNode[]...;
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