type ModulesItem record {
    string name;
};

type PackagesItem record {
    string organization;
    string name;
    string version;
    string icon;
    string[] keywords;
    ModulesItem[] modules;
};

type Query record {
    PackagesItem[] packages;
};

type Data record {
    Query query;
};

type GQLPackagesResponse record {
    Data data;
};

type DocsModulesItem record {
    string clients;
    string listeners;
    string functions;
};

type DocsDataItem record {
    DocsModulesItem[] modules;
};

type DoscQuery record {
    DocsDataItem docsData;
};

type DocsData record {
    DoscQuery query;
};

type GQLDocsResponse record {
    DocsData data;
};
