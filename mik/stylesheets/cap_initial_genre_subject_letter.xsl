<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:mods="http://www.loc.gov/mods/v3"
    xpath-default-namespace="http://www.loc.gov/mods/v3" exclude-result-prefixes="xs" version="2.0"
    xmlns="http://www.loc.gov/mods/v3">

    <!-- for subject topic, genre, and occupation
     capitalizes first letter and remove period if it ends the string
     
     for subject geographic, capitalizes first letter, does not remove
       any periods
       
     for others, passes them through as-is.
    -->

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="//mods:genre">
        <xsl:element name="genre">
            <xsl:for-each select="@*">
                <xsl:variable name="aname"><xsl:value-of select="name()"/></xsl:variable>
                <xsl:attribute name="{$aname}"><xsl:value-of select="."/></xsl:attribute>
            </xsl:for-each>
            <xsl:value-of
                select="replace(replace(concat(upper-case(substring(., 1, 1)), substring(., 2)), '^\s+|\s+$', ''), '\.$', '')"
            />
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="//mods:subject">
        <xsl:element name="subject">
            <xsl:for-each select="@*">
                <xsl:variable name="aname">
                    <xsl:value-of select="name()"/>
                </xsl:variable>
                <xsl:attribute name="{$aname}"><xsl:value-of select="."/></xsl:attribute>
            </xsl:for-each>
            
            <xsl:for-each select="./*">
                <xsl:variable name="ename">
                    <xsl:value-of select="name(.)"/>
                </xsl:variable>
                
                <xsl:element name="{$ename}">
                    <xsl:for-each select="@*">
                        <xsl:variable name="aname">
                            <xsl:value-of select="name()"/>
                        </xsl:variable>
                        <xsl:attribute name="{$aname}"><xsl:value-of select="."/></xsl:attribute>
                    </xsl:for-each>
                    
                    <xsl:choose>
                        <xsl:when test="$ename='cartographics'">
                            <xsl:copy-of select="node()"/>
                        </xsl:when>
                        
                        <xsl:when test="$ename='genre'">
                            <xsl:value-of
                                select="replace(replace(concat(upper-case(substring(., 1, 1)), substring(., 2)), '^\s+|\s+$', ''), '\.$', '')"
                            />
                        </xsl:when>

                        <xsl:when test="$ename='geographic'">
                            <xsl:value-of
                                select="replace(concat(upper-case(substring(., 1, 1)), substring(., 2)), '^\s+|\s+$', '')"
                            />
                        </xsl:when>
                        
                        <xsl:when test="$ename='geographicCode'">
                            <xsl:copy-of select="node()"/>
                        </xsl:when>
                        
                        <xsl:when test="$ename='hierarchicalGeographic'">
                            <xsl:copy-of select="node()"/>
                        </xsl:when>
                        
                        <xsl:when test="$ename='name'">
                            <xsl:copy-of select="node()"/>
                        </xsl:when>
                        
                        <xsl:when test="$ename='occupation'">
                            <xsl:value-of
                                select="replace(replace(concat(upper-case(substring(., 1, 1)), substring(., 2)), '^\s+|\s+$', ''), '\.$', '')"
                            />
                        </xsl:when>
                        
                        <xsl:when test="$ename='temporal'">
                            <xsl:value-of
                                select="replace(replace(concat(upper-case(substring(., 1, 1)), substring(., 2)), '^\s+|\s+$', ''), '\.$', '')"
                            />
                        </xsl:when>
                        
                        <xsl:when test="$ename='titleInfo'">
                            <xsl:copy-of select="node()"/>
                        </xsl:when>
                        
                        <xsl:when test="$ename='topic'">
                            <xsl:value-of
                                select="replace(replace(concat(upper-case(substring(., 1, 1)), substring(., 2)), '^\s+|\s+$', ''), '\.$', '')"
                            />
                        </xsl:when>
                    </xsl:choose>
                </xsl:element>
            </xsl:for-each>
        </xsl:element>
    </xsl:template>


</xsl:stylesheet>
