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
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.ClassSymbol;
import io.ballerina.compiler.api.symbols.Qualifier;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.SymbolKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.VariableSymbol;
import io.ballerina.compiler.syntax.tree.ModulePartNode;
import io.ballerina.compiler.syntax.tree.NonTerminalNode;
import io.ballerina.compiler.syntax.tree.SyntaxTree;
import io.ballerina.flowmodelgenerator.core.central.Central;
import io.ballerina.flowmodelgenerator.core.central.CentralProxy;
import io.ballerina.flowmodelgenerator.core.model.Diagram;
import io.ballerina.flowmodelgenerator.core.model.FlowNode;
import io.ballerina.flowmodelgenerator.core.model.Property;
import io.ballerina.projects.Document;
import io.ballerina.tools.text.LineRange;
import io.ballerina.tools.text.TextDocument;
import io.ballerina.tools.text.TextRange;

import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/**
 * Generator for the flow model.
 *
 * @since 1.4.0
 */
public class ModelGenerator {

    private final SemanticModel semanticModel;
    private final Document document;
    private final LineRange lineRange;
    private final Path filePath;
    private final Gson gson;

    public ModelGenerator(SemanticModel model, Document document, LineRange lineRange, Path filePath) {
        this.semanticModel = model;
        this.document = document;
        this.lineRange = lineRange;
        this.filePath = filePath;
        this.gson = new GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create();
    }

    /**
     * Generates a flow model for the given canvas node.
     *
     * @return JSON representation of the flow model
     */
    public JsonElement getFlowModel() {
        // Obtain the code block representing the canvas
        SyntaxTree syntaxTree = document.syntaxTree();
        TextDocument textDocument = syntaxTree.textDocument();
        ModulePartNode modulePartNode = syntaxTree.rootNode();
        int start = textDocument.textPositionFrom(lineRange.startLine());
        int end = textDocument.textPositionFrom(lineRange.endLine());
        NonTerminalNode canvasNode = modulePartNode.findNode(TextRange.from(start, end - start), true);

        // Obtain the connections visible at the module-level
        List<FlowNode> moduleConnections =
                semanticModel.visibleSymbols(document, modulePartNode.lineRange().startLine()).stream()
                        .flatMap(symbol -> buildConnection(syntaxTree, symbol).stream())
                        .sorted(Comparator.comparing(node -> node.properties().get(Property.VARIABLE_KEY).value()))
                        .toList();

        // Analyze the code block to find the flow nodes
        CodeAnalyzer codeAnalyzer = new CodeAnalyzer(semanticModel);
        canvasNode.accept(codeAnalyzer);

        // Generate the flow model
        Diagram diagram = new Diagram(filePath.toString(), codeAnalyzer.getFlowNodes(), moduleConnections);
        return gson.toJsonTree(diagram);
    }

    /**
     * Builds a client from the given type symbol.
     *
     * @return the client if the type symbol is a client, otherwise empty
     */
    private Optional<FlowNode> buildConnection(SyntaxTree syntaxTree, Symbol symbol) {
        NonTerminalNode node;
        try {
            TypeSymbol typeSymbol = ((VariableSymbol) symbol).typeDescriptor();
            TypeSymbol typeDescriptorSymbol = ((TypeReferenceTypeSymbol) typeSymbol).typeDescriptor();
            if (typeDescriptorSymbol.kind() != SymbolKind.CLASS ||
                    !((ClassSymbol) typeDescriptorSymbol).qualifiers().contains(Qualifier.CLIENT)) {
                return Optional.empty();
            }
            node = symbol.getLocation().map(loc -> CommonUtils.getNode(syntaxTree, loc.textRange())).orElseThrow();
        } catch (RuntimeException ignored) {
            return Optional.empty();
        }
        CodeAnalyzer codeAnalyzer = new CodeAnalyzer(semanticModel);
        node.parent().parent().accept(codeAnalyzer);
        List<FlowNode> connections = codeAnalyzer.getFlowNodes();
        return connections.stream().findFirst();
    }
}
