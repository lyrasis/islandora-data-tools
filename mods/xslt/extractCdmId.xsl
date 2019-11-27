<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mods="http://www.loc.gov/mods/v3"
    xpath-default-namespace="http://www.loc.gov/mods/v3"
    exclude-result-prefixes="xs"
    version="2.0"
    xmlns="http://www.loc.gov/mods/v3" >
    <xsl:output method="text"/>
    <!-- If the namePart is blank, then delete the name node -->
    <xsl:template match="/">
         
        <xsl:copy-of select="//identifier[@type='CONTENTdm ID']"/>
    
    </xsl:template>


</xsl:stylesheet>
