<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:mods="http://www.loc.gov/mods/v3"
    xpath-default-namespace="http://www.loc.gov/mods/v3" exclude-result-prefixes="xs" version="2.0"
    xmlns="http://www.loc.gov/mods/v3">

    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="mods" exclude-result-prefixes="#all">
        <xsl:copy>
            <!--
                Title explictly specified as primary is first.
                Title with no type and not specified as primary next.
                Other typed titles in original order.
            -->
            <xsl:apply-templates select="titleInfo[@usage = 'primary']"/>
            <xsl:apply-templates select="titleInfo[not(@type) and not(@usage)]"/>
            <xsl:apply-templates select="titleInfo[(@type) and not(@usage)]"/>
            <xsl:apply-templates select="part"/>
            <!-- Corporate names last, followed by untyped names -->
            <xsl:apply-templates select="name[(@type = 'personal') and (role/roleTerm = 'author')]"/>
            <xsl:apply-templates select="name[(@type = 'personal') and (role/roleTerm = 'creator')]"/>
            <xsl:apply-templates select="name[(@type = 'corporate') and (role/roleTerm = 'author')]"/>
            <xsl:apply-templates select="name[(@type = 'corporate') and (role/roleTerm = 'creator')]"/>
            <xsl:apply-templates select="name[(@type = 'personal') and (role/roleTerm = 'interviewee')]"/>
            <xsl:apply-templates select="name[(@type = 'personal') and (role/roleTerm = 'interviewer')]"/>
            <xsl:apply-templates select="name[(@type = 'personal') and (role/roleTerm = 'contributor')]"/>
            <xsl:apply-templates select="name[(@type = 'personal') and not(role/roleTerm = 'author') and not(role/roleTerm = 'creator') and not(role/roleTerm = 'interviewee') and not(role/roleTerm = 'interviewer') and not(role/roleTerm = 'contributor')]"/>
            <xsl:apply-templates select="name[@type = 'family']"/>
            <xsl:apply-templates select="name[@type = 'conference']"/>           
            <xsl:apply-templates select="name[(@type = 'corporate') and (role/roleTerm = 'contributor')]"/>
            <xsl:apply-templates select="name[(@type = 'corporate') and not(role/roleTerm = 'author') and not(role/roleTerm = 'creator') and not(role/roleTerm = 'contributor')]"/>
            <xsl:apply-templates select="name[not(@type)]"/>
            <xsl:apply-templates select="originInfo"/>
            <xsl:apply-templates select="subject"/>
            <xsl:apply-templates select="abstract"/>
            <xsl:apply-templates select="note[@type = 'content']"/>
            <xsl:apply-templates select="tableOfContents"/>
            <xsl:apply-templates select="typeOfResource"/>
            <xsl:apply-templates select="physicalDescription"/>
            <xsl:apply-templates select="genre"/>
            <xsl:apply-templates select="note[@type = 'system details']"/>
            <xsl:apply-templates select="language"/>
            <!-- all other types of notes and nontyped notes, in original order -->
            <xsl:apply-templates
                select="note[not(@type = 'content') and not(@type = 'ownership') and not(@type = 'preferred citation') and not(@type = 'system details')]"/>
            <xsl:apply-templates select="note[@type = 'ownership']"/>
            <xsl:apply-templates select="targetAudience"/>
            <xsl:apply-templates select="relatedItem"/>
            <xsl:apply-templates select="location"/>
            <xsl:apply-templates select="classification"/>
            <xsl:apply-templates select="accessCondition"/>
            <xsl:apply-templates select="note[@type = 'preferred citation']"/>
            <xsl:apply-templates select="identifier"/>
            <xsl:apply-templates select="recordInfo"/>
            <xsl:apply-templates select="extension"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="originInfo" exclude-result-prefixes="#all">
        <xsl:copy>
            <xsl:apply-templates select="place"/>
            <xsl:apply-templates select="publisher"/>
            <xsl:apply-templates select="*[@keyDate = 'yes']"/>
            <xsl:apply-templates select="dateCreated[not(@keyDate)]"/>
            <xsl:apply-templates select="dateIssued[not(@keyDate)]"/>
            <xsl:apply-templates select="copyrightDate[not(@keyDate)]"/>
            <xsl:apply-templates select="dateOther[not(@keyDate)]"/>
            <xsl:apply-templates select="dateCaptured[not(@keyDate)]"/>
            <xsl:apply-templates select="dateModified[not(@keyDate)]"/>
            <xsl:apply-templates select="dateValid[not(@keyDate)]"/>
            <xsl:apply-templates select="edition"/>
            <xsl:apply-templates select="issuance"/>
            <xsl:apply-templates select="frequency"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>
