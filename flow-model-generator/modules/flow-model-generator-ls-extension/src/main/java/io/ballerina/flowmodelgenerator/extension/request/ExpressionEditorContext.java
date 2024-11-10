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

package io.ballerina.flowmodelgenerator.extension.request;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import io.ballerina.flowmodelgenerator.core.model.FlowNode;
import io.ballerina.flowmodelgenerator.core.model.Property;
import io.ballerina.tools.text.LinePosition;

import java.util.Optional;

/**
 * Represents the context for the expression editor.
 *
 * @param expression The modified expression
 * @param startLine  The start line of the node
 * @param offset     The offset of cursor compared to the start of the expression
 * @param node       The node which contains the expression
 * @param branch     The branch of the expression if exists
 * @param property   The property of the expression
 */
public record ExpressionEditorContext(String expression, LinePosition startLine, int offset, JsonObject node,
                                      String branch, String property) {

    private static final Gson gson = new Gson();

    public Optional<Property> getProperty() {
        FlowNode flowNode = gson.fromJson(node.toString(), FlowNode.class);
        if (branch == null || branch.isEmpty()) {
            return flowNode.getProperty(property);
        }
        return flowNode.getBranch(branch).flatMap(branch -> branch.getProperty(property));
    }
}
