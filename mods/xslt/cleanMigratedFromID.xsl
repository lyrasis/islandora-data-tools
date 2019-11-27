<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mods="http://www.loc.gov/mods/v3"
    xpath-default-namespace="http://www.loc.gov/mods/v3"
    exclude-result-prefixes="xs"
    version="2.0"
    xmlns="http://www.loc.gov/mods/v3" >
    
    
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="identifier[@displayLabel='Migrated From']">
        <xsl:element name="identifier">
            <xsl:attribute name="type">CONTENTdm ID</xsl:attribute>
            <xsl:attribute name="invalid">yes</xsl:attribute>
            <xsl:value-of select="substring(.,2)"/>
        </xsl:element>
        
    </xsl:template>
</xsl:stylesheet>
