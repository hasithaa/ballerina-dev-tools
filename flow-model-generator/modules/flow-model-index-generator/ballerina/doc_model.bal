type Type record {
    string name;
    string category;
    boolean isAnonymousUnionType;
    boolean isInclusion;
    boolean isArrayType;
    boolean isNullable;
    boolean isTuple;
    boolean isIntersectionType;
    boolean isParenthesisedType;
    boolean isTypeDesc;
    boolean isRestParam;
    boolean isDeprecated;
    boolean isPublic;
    boolean generateUserDefinedTypeLink;
    Type[] memberTypes;
    Type elementType?;
    int arrayDimensions;
};


type ParametersItem record {
    string defaultValue;
    Type 'type;
    string name;
    string description;
    boolean isDeprecated;
    boolean isReadOnly;
};


type ReturnParametersItem record {
    Type 'type;
    string name;
    string description;
    boolean isDeprecated;
    boolean isReadOnly;
};

type FunctionItem record {
    string accessor;
    string resourcePath;
    boolean isIsolated;
    boolean isRemote;
    boolean isResource;
    boolean isExtern;
    ParametersItem[] parameters;
    ReturnParametersItem[] returnParameters;
    anydata[] annotationAttachments;
    string name;
    string description;
    anydata[] descriptionSections;
    boolean isDeprecated;
    boolean isReadOnly;
};
