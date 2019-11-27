<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:mods="http://www.loc.gov/mods/v3"
    xpath-default-namespace="http://www.loc.gov/mods/v3" exclude-result-prefixes="xs" version="2.0"
    xmlns="http://www.loc.gov/mods/v3">

    <!-- If the namePart is blank, then delete the name node -->

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="name">
        <xsl:choose>
            <xsl:when test="namePart = ''"> </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="*"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

<!-- Keeps relatedItem nodes that are blank (only xlink:href should be like this.)
     Keeps relatedItem nodes with an identifier child, whether or not there is a title.
     Deletes relatedItems nodes with no identifier child if the titleInfo/title is missing or blank-->
    <xsl:template match="relatedItem">
        <xsl:choose>
        <xsl:when test=". = ''">
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="*"/>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="not(identifier) and (not(titleInfo/title) or (titleInfo/title = ''))">                
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="*"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
