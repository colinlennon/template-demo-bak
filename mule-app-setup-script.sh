#!/bin/bash

# Pre-requisites:
#   - git command-line tool installed and configured correctly
#   - Git Bash??? TBC
#   - GitHub Personal Access Token created and set in environment variable - TODO we could validate this
#   - Others? TBC...
clear
printf "Welcome to the Bayer DTEF Mule App Setup Script!\n\n"

#printf -v PROJECT_NAME '%q' "${PWD##*/}"
#echo "The name of this directory is: $PROJECT_NAME\n"
#echo "This will be used to name the Mule interface and implementation XML configuration files accordingly\n"

#echo "Detecting Maven project's groupId, artifactId and version..."
printf "Detecting Maven project's groupId...\n"
API_GROUP_ID=$(mvn org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate -Dexpression=project.groupId -q -DforceStdout)
#API_ARTIFACT_ID=$(mvn org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate -Dexpression=project.artifactId -q -DforceStdout)
#API_VERSION=$(mvn org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate -Dexpression=project.version -q -DforceStdout)

printf "Now, we need the details of the API specification being implemented in this Mule application.\n"
printf "Please ensure that you have published your latest stable version of the API specification to Exchange before continuing!\n\n"
#read -p "Please enter the ID of your business group/workspace (this will be used to set the groupId in the pom.xml): " API_GROUP_ID #TODO can we default this to the EF Intermediate ID?
read -p "Please enter the name of the API specification asset in Exchange (e.g. rest-api-template-spec): " API_ARTIFACT_ID
read -p "Please enter the version of the API specification (e.g. 1.0.0): " API_VERSION

printf "Using groupId $API_GROUP_ID\n"
printf "Using artifactId $API_ARTIFACT_ID\n"
printf "Using version $API_VERSION\n\n"

# Get GitHub PAT (could remove this and have setting an environment variable as a pre-requisite instead...)
read -p "Please provide a GitHub Personal Access Token (PAT) which can be used to create a repository for this Mule app: " GITHUB_PAT

# Remove the rest-api-template-spec dependency 
printf "Removing the rest-api-template-spec dependency from pom.xml..\n"
REST_API_TEMPLATE_DEPENDECY_START=$(grep -n "<!-- START: rest-api-template dependency -->" pom.xml | cut -d : -f 1) # TODO: put this in the template!!!
REST_API_TEMPLATE_DEPENDECY_END=$(($REST_API_TEMPLATE_DEPENDECY_START + 7))
REST_API_TEMPLATE_DEPENDECY_END="${REST_API_TEMPLATE_DEPENDECY_END}d"
RES=$(sed -i "$REST_API_TEMPLATE_DEPENDECY_START,$REST_API_TEMPLATE_DEPENDECY_END" pom.xml)

# Add the API spec dependency
printf "Adding the $API_ARTIFACT_ID dependency to pom.xml...\n"
API_SPEC_DEPENDENCY=$"<dependency>\\n"
API_SPEC_DEPENDENCY+=$"            <groupId>$API_GROUP_ID</groupId>\\n"
API_SPEC_DEPENDENCY+=$"            <artifactId>$API_ARTIFACT_ID</artifactId>\\n"
API_SPEC_DEPENDENCY+=$"            <version>$API_VERSION</version>\\n"
API_SPEC_DEPENDENCY+=$"            <classifier>raml</classifier>\\n"
API_SPEC_DEPENDENCY+=$"            <type>zip</type>\\n"
API_SPEC_DEPENDENCY+=$"        </dependency>"
sed -i "s,<\!-- PLACEHOLDER: api-spec dependency -->,$API_SPEC_DEPENDENCY," pom.xml

printf "Updating  src/main/mule/api.xml...\n"
RES=$(sed -i "s+name=\"api-httpListenerConfig\"+name=\"$API_ARTIFACT_ID-httpListenerConfig\"+" src/main/mule/api.xml)
RES=$(sed -i "s+<apikit:config name=\"api-config\"+<apikit:config name=\"$API_ARTIFACT_ID-config\"+" src/main/mule/api.xml)
#	- Search for and replace: api="resource::9603fc66-9985-4754-8a84-6dfcfc3b2d72:rest-api-template-spec:1.0.1:raml:zip:api.raml" (note: will need to update this for Bayer template)
RES=$(sed -i "s+api=\"resource::4662d833-1567-4253-b115-eb71a03c7051:rest-api-template-spec:1.0.0:raml:zip:api.raml\"+api=\"resource::$API_GROUP_ID:$API_ARTIFACT_ID:$API_VERSION:raml:zip:$API_ARTIFACT_ID.raml\"+" src/main/mule/api.xml)
RES=$(sed -i "s+<http:listener config-ref=\"api-httpListenerConfig\"+<http:listener config-ref=\"$API_ARTIFACT_ID-httpListenerConfig\"+" src/main/mule/api.xml)
RES=$(sed -i "s+<apikit:router config-ref=\"api-config\"+<apikit:router config-ref=\"$API_ARTIFACT_ID-config\"+" src/main/mule/api.xml)
RES=$(sed -i "s+<flow name=\"api-main\">+<flow name=\"$API_ARTIFACT_ID-main\">+" src/main/mule/api.xml)
RES=$(sed -i "s+<flow name=\"get:\\\ping:api-config\">+<flow name=\"get:\ping:$API_ARTIFACT_ID-config\">+" src/main/mule/api.xml) 

printf "Updating src/main/mule/common/global.xml...\n"
RES=$(sed -i "s+flowRef=\"api-main\"+flowRef=\"$API_ARTIFACT_ID-main\"+" src/main/mule/common/global.xml)

printf "Renaming Mule XML configuration files...\n"
RES=$(mv src/main/mule/api.xml src/main/mule/${API_ARTIFACT_ID}-api.xml)
RES=$(mv src/main/mule/implementation/api-impl.xml src/main/mule/implementation/${API_ARTIFACT_ID}-api-impl.xml)

printf "Initialising local git repo and performing first commit...\n"
git init
git add -A
git commit -m "Initial commit (from mule-app-setup-script)"
git branch -M main

# TODO create GitHub repo - here is a working example command
curl -X POST -H "Authorization: token $GITHUB_PAT" https://api.github.com/user/repos -d "{\"name\": \"$API_ARTIFACT_ID\"}"

# TODO need to parameterise the line below
RES=$(git remote add origin https://github.com/colinlennon/$API_ARTIFACT_ID.git)
git push -u origin main