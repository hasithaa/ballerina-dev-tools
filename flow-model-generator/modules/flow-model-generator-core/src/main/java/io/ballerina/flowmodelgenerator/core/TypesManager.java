/*
 *  Copyright (c) 2024, WSO2 LLC. (http://www.wso2.com)
 *
 *  WSO2 LLC. licenses this file to you under the Apache License,
 *  Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

package io.ballerina.flowmodelgenerator.core;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.ArrayTypeSymbol;
import io.ballerina.compiler.api.symbols.RecordFieldSymbol;
import io.ballerina.compiler.api.symbols.RecordTypeSymbol;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeDefinitionSymbol;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.compiler.syntax.tree.ModulePartNode;
import io.ballerina.compiler.syntax.tree.SyntaxTree;
import io.ballerina.flowmodelgenerator.core.model.Member;
import io.ballerina.flowmodelgenerator.core.model.ModuleInfo;
import io.ballerina.flowmodelgenerator.core.model.NodeKind;
import io.ballerina.flowmodelgenerator.core.model.TypeData;
import io.ballerina.flowmodelgenerator.core.utils.CommonUtils;
import io.ballerina.flowmodelgenerator.core.utils.TypeTransformer;
import io.ballerina.flowmodelgenerator.core.utils.TypeUtils;
import io.ballerina.projects.Document;
import io.ballerina.projects.Module;
import io.ballerina.tools.text.LinePosition;
import io.ballerina.tools.text.LineRange;
import org.eclipse.lsp4j.TextEdit;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Predicate;
import java.util.stream.Collectors;

/**
 * Manage creation, retrieving and updating operations related to types.
 *
 * @since 2.0.0
 */
public class TypesManager {
    private static final Gson gson = new Gson();
    private final Module module;
    private final Document typeDocument;
    private static final List<SymbolKind> supportedSymbolKinds = List.of(SymbolKind.TYPE_DEFINITION, SymbolKind.ENUM,
            SymbolKind.SERVICE_DECLARATION, SymbolKind.CLASS);

    private static final Predicate<Symbol> supportedTypesPredicate = symbol -> {
        if (symbol.getName().isEmpty()) {
            return false;
        }

        if (symbol.kind() == SymbolKind.ENUM) {
            return true;
        }

        if (symbol.kind() != SymbolKind.TYPE_DEFINITION) {
            return false;
        }

        return switch (((TypeDefinitionSymbol) symbol).typeDescriptor().typeKind()) {
            case RECORD, ARRAY, UNION, ERROR -> true;
            default -> false;
        };
    };

    public TypesManager(Document typeDocument) {
        this.typeDocument = typeDocument;
        this.module = typeDocument.module();
    }

    public JsonElement getAllTypes() {
        SemanticModel semanticModel = this.module.getCompilation().getSemanticModel();
        Map<String, Symbol> symbolMap = semanticModel.moduleSymbols().stream()
                .filter(supportedTypesPredicate)
                .collect(Collectors.toMap(symbol -> symbol.getName().get(), symbol -> symbol));

        // Now we have all the defined types in the module scope
        // Now we need to get foreign types that we have defined members of the types
        // e.g: ballerina\time:UTC in Person record as a type of field `dateOfBirth`
        new HashMap<>(symbolMap).forEach((key, element) -> {
            if (element.kind() != SymbolKind.TYPE_DEFINITION) {
                return;
            }
            TypeSymbol typeSymbol = ((TypeDefinitionSymbol) element).typeDescriptor();
            addMemberTypes(typeSymbol, symbolMap);
        });

        List<Object> allTypes = new ArrayList<>();
        TypeTransformer typeTransformer = new TypeTransformer(this.module);
        symbolMap.values().forEach(symbol -> {
            if (symbol.kind() == SymbolKind.TYPE_DEFINITION) {
                TypeDefinitionSymbol typeDef = (TypeDefinitionSymbol) symbol;
                if (typeDef.typeDescriptor().typeKind() == TypeDescKind.RECORD) {
                    allTypes.add(typeTransformer.transform(typeDef));
                }
            }
        });

        return gson.toJsonTree(allTypes);
    }

    public JsonElement getType(Document document, LinePosition linePosition) {
        SemanticModel semanticModel = this.module.getCompilation().getSemanticModel();
        Optional<Symbol> symbol = semanticModel.symbol(document, linePosition);
        if (symbol.isEmpty() || !supportedSymbolKinds.contains(symbol.get().kind())) {
            return null;
        }

        switch (symbol.get().kind()) {
            case TYPE_DEFINITION -> {
                TypeDefinitionSymbol typeDef = (TypeDefinitionSymbol) symbol.get();
                TypeTransformer typeTransformer = new TypeTransformer(this.module);
                return gson.toJsonTree(typeTransformer.transform(typeDef));
            }
            case SERVICE_DECLARATION -> {
                return null;
            }
            case CLASS -> {
                return null;
            }
            case ENUM -> {
                return null;
            }
            default -> {
                return null;
            }
        }
    }

    public JsonElement updateType(Path filePath, TypeData typeData) {
        List<TextEdit> textEdits = new ArrayList<>();
        Map<Path, List<TextEdit>> textEditsMap = new HashMap<>();
        textEditsMap.put(filePath, textEdits);

        if (NodeKind.RECORD.equals(typeData.codedata().node())) {
            String recordTypeDef = createRecordTypeDefCodeSnippet(typeData);
            LineRange lineRange = typeData.codedata().lineRange();
            if (lineRange == null) {
                SyntaxTree syntaxTree = this.typeDocument.syntaxTree();
                ModulePartNode modulePartNode = syntaxTree.rootNode();
                LinePosition startPos = LinePosition.from(modulePartNode.lineRange().endLine().line() + 1, 0);
                textEdits.add(new TextEdit(CommonUtils.toRange(startPos), recordTypeDef));
            } else {
                textEdits.add(new TextEdit(CommonUtils.toRange(lineRange), recordTypeDef));
            }
        }

        return gson.toJsonTree(textEditsMap);
    }

    private void addMemberTypes(TypeSymbol typeSymbol, Map<String, Symbol> symbolMap) {
        // Record
        switch (typeSymbol.typeKind()) {
            case RECORD -> {
                RecordTypeSymbol recordTypeSymbol = (RecordTypeSymbol) typeSymbol;

                // Type inclusions
                List<TypeSymbol> inclusions = recordTypeSymbol.typeInclusions();
                inclusions.forEach(inc -> {
                    addToMapIfForeignAndNotAdded(symbolMap, inc);
                });

                // Rest field
                Optional<TypeSymbol> restTypeDescriptor = recordTypeSymbol.restTypeDescriptor();
                if (restTypeDescriptor.isPresent()) {
                    TypeSymbol restType = restTypeDescriptor.get();
                    addToMapIfForeignAndNotAdded(symbolMap, restType);
                }

                // Field members
                Map<String, RecordFieldSymbol> fieldSymbolMap = recordTypeSymbol.fieldDescriptors();
                fieldSymbolMap.forEach((key, field) -> {
                    TypeSymbol ts = field.typeDescriptor();
                    if (ts.typeKind() == TypeDescKind.ARRAY || ts.typeKind() == TypeDescKind.UNION) {
                        addMemberTypes(ts, symbolMap);
                    } else {
                        addToMapIfForeignAndNotAdded(symbolMap, ts);
                    }
                });
            }
            case UNION -> {
                UnionTypeSymbol unionTypeSymbol = (UnionTypeSymbol) typeSymbol;
                List<TypeSymbol> unionMembers = unionTypeSymbol.memberTypeDescriptors();
                unionMembers.forEach(member -> {
                    if (member.typeKind() == TypeDescKind.ARRAY) {
                        addMemberTypes(member, symbolMap);
                    } else {
                        addToMapIfForeignAndNotAdded(symbolMap, member);
                    }
                });
            }
            case ARRAY -> {
                ArrayTypeSymbol arrayTypeSymbol = (ArrayTypeSymbol) typeSymbol;
                TypeSymbol arrMemberTypeDesc = arrayTypeSymbol.memberTypeDescriptor();
                if (arrMemberTypeDesc.typeKind() == TypeDescKind.ARRAY
                        || arrMemberTypeDesc.typeKind() == TypeDescKind.UNION) {
                    addMemberTypes(arrMemberTypeDesc, symbolMap);
                } else {
                    addToMapIfForeignAndNotAdded(symbolMap, arrMemberTypeDesc);
                }
            }
            default -> {
            }
        }
    }

    private void addToMapIfForeignAndNotAdded(Map<String, Symbol> foreignSymbols, TypeSymbol type) {
        if (type.typeKind() != TypeDescKind.TYPE_REFERENCE
                || type.getName().isEmpty()
                || type.getModule().isEmpty()) {
            return;
        }

        String name = type.getName().get();

        if (CommonUtils.isWithinPackage(type, ModuleInfo.from(this.module.descriptor()))) {
            return;
        }

        String typeName = TypeUtils.generateReferencedTypeId(type, ModuleInfo.from(this.module.descriptor()));
        if (!foreignSymbols.containsKey(name)) {
            foreignSymbols.put(typeName, type);
        }
    }

    private String createRecordTypeDefCodeSnippet(TypeData typeData) {
        StringBuilder recordBuilder = new StringBuilder();

        // Add documentation if present
        if (typeData.metadata().description() != null && !typeData.metadata().description().isEmpty()) {
            recordBuilder.append(CommonUtils.convertToBalDocs(typeData.metadata().description()));
        }

        // Add type name
        recordBuilder.append("type ")
                .append(typeData.name())
                .append(" record {|\n");

        // Add includes
        for (String include : typeData.includes()) {
            recordBuilder.append("*").append(include).append(";\n");
        }

        // Add members
        for (Map.Entry<String, Member> entry : typeData.members().entrySet()) {
            String memberName = entry.getKey();
            Member member = entry.getValue();

            if (member.docs() != null && !member.docs().isEmpty()) {
                recordBuilder.append(CommonUtils.convertToBalDocs(member.docs()));
            }

            recordBuilder
                    .append(member.type())
                    .append(" ")
                    .append(memberName)
                    .append((member.defaultValue() != null && !member.defaultValue().isEmpty()) ?
                            " = " + member.defaultValue() : "")
                    .append(";\n");
        }

        // Add rest member if present
        Optional.ofNullable(typeData.restMember()).ifPresent(restMember -> {
            recordBuilder
                    .append(restMember.type())
                    .append("...;\n");
        });

        // Close the record
        recordBuilder.append("|};\n");

        return recordBuilder.toString();
    }
}
