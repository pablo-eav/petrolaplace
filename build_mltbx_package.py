import os
import zipfile
import datetime
import xml.etree.ElementTree as ET

REPO_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_MLTBX = os.path.join(REPO_DIR, "PetroLaplace.mltbx")

print(f"Building official MATLAB Toolbox (.mltbx): {OUTPUT_MLTBX}")

# Files and folders to include in fsroot
FS_ENTRIES = [
    "+petrolaplace",
    "app",
    "data",
    "doc",
    "examples",
    "src",
    "tests",
    "Contents.m",
    "info.xml",
    "LICENSE",
    "README.md",
    "start_toolbox.m",
    "uninstall_toolbox.m",
    "petrolaplace_logo.png"
]

# Excluded extensions
EXCLUDED_EXTS = {".asv", ".bak", ".tmp", ".pyc", ".git", ".gitignore"}

# Collect all files for fsroot
file_list = []
for entry in FS_ENTRIES:
    full_path = os.path.join(REPO_DIR, entry)
    if os.path.isfile(full_path):
        rel = os.path.relpath(full_path, REPO_DIR).replace("\\", "/")
        file_list.append((full_path, "/" + rel))
    elif os.path.isdir(full_path):
        for root, dirs, files in os.walk(full_path):
            if "__pycache__" in root or ".git" in root:
                continue
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in EXCLUDED_EXTS:
                    continue
                p = os.path.join(root, f)
                rel = os.path.relpath(p, REPO_DIR).replace("\\", "/")
                file_list.append((p, "/" + rel))

print(f"Total files to package into fsroot: {len(file_list)}")

# Build filesystemManifest.xml
manifest_lines = [
    '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>',
    '<fileEntries xmlns="http://schemas.mathworks.com/package/2013/filesystemManifest" createdByEncoding="UTF-8" createdByPlatform="win64" version="2.0">'
]
now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

for local_path, rel_in_fs in sorted(file_list, key=lambda x: x[1]):
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(local_path), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest_lines.append(f'  <fileEntry content="/fsroot{rel_in_fs}" date="{mtime}" name="{rel_in_fs}" permissions="0750" type="File"/>')
manifest_lines.append('</fileEntries>')
manifest_xml = "\n".join(manifest_lines)

# Metadata XMLs
addon_props_xml = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<addonProperties xmlns="http://schemas.mathworks.com/matlab/addon/2014/addonProperties">
  <identifier type="GUID">d5e8a1b2-c3f4-4e5a-8b9c-0d1e2f3a4b5c</identifier>
  <description>PetroLaplace Reservoir Core: Advanced Well Test Analysis &amp; Non-Iterative Deconvolution Toolbox for Petroleum Reservoir Engineering.</description>
  <authors>
    <author>
      <name>Prof. Pablo Enrique Aballe Vázquez</name>
      <contact>support@laplace-rootfree.org</contact>
      <organization>Instituto Internacional de Investigación Laplace</organization>
    </author>
  </authors>
</addonProperties>'''

configuration_xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<configuration xmlns="http://schemas.mathworks.com/matlab/addon/2014/configuration">
  <matlabPaths>
    <matlabPath></matlabPath>
    <matlabPath>/app</matlabPath>
    <matlabPath>/examples</matlabPath>
    <matlabPath>/tests</matlabPath>
    <matlabPath>/doc</matlabPath>
    <matlabPath>/data</matlabPath>
  </matlabPaths>
  <infoXMLPath>info.xml</infoXMLPath>
</configuration>'''

core_properties_xml = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dcterms:created xsi:type="dcterms:W3CDTF">{now_iso}</dcterms:created>
  <dc:creator>Prof. Pablo Enrique Aballe Vázquez</dc:creator>
  <dc:description>Advanced Well Test Analysis &amp; Non-Iterative Deconvolution Toolbox for Petroleum Reservoir Engineering.</dc:description>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now_iso}</dcterms:modified>
  <dc:title>PetroLaplace Reservoir Core</dc:title>
  <cp:version>1.0.3</cp:version>
</cp:coreProperties>'''

mwcore_xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<mwcoreProperties xmlns="http://schemas.mathworks.com/package/2012/coreProperties">
  <contentType>application/vnd.mathworks.matlab.toolbox</contentType>
  <contentTypeFriendlyName>MATLAB Toolbox</contentTypeFriendlyName>
  <matlabRelease>R2024b</matlabRelease>
</mwcoreProperties>'''

mwcore_ext_xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<mwcorePropertiesExtension xmlns="http://schemas.mathworks.com/package/2014/corePropertiesExtension">
  <stringProperty name="product">MATLAB</stringProperty>
</mwcorePropertiesExtension>'''

system_req_xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<systemRequirements xmlns="http://schemas.mathworks.com/matlab/addon/2014/systemRequirements">
  <platformCompatibility MATLABOnline="true" linux="true" mac="true" win="true"/>
  <releaseCompatibility end="latest" start="R2020a"/>
</systemRequirements>'''

rels_xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Target="metadata/addonProperties.xml" Type="http://schemas.mathworks.com/matlab/addon/2014/relationships/addonProperties"/>
  <Relationship Id="rId100" Target="metadata/primaryScreenShot.png" Type="http://schemas.mathworks.com/matlab/addon/2014/relationships/primaryScreenShot"/>
  <Relationship Id="rId101" Target="metadata/primaryScreenShot.png" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail"/>
  <Relationship Id="rId2" Target="metadata/mwcoreProperties.xml" Type="http://schemas.mathworks.com/package/2012/relationships/coreProperties"/>
  <Relationship Id="rId3" Target="metadata/mwcorePropertiesExtension.xml" Type="http://schemas.mathworks.com/package/2014/relationships/corePropertiesExtension"/>
  <Relationship Id="rId5" Target="metadata/coreProperties.xml" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"/>
  <Relationship Id="rId6" Target="metadata/filesystemManifest.xml" Type="http://schemas.mathworks.com/package/2013/relationships/filesystemManifest"/>
  <Relationship Id="rId7" Target="metadata/configuration.xml" Type="http://schemas.mathworks.com/matlab/addon/2014/relationships/configuration"/>
  <Relationship Id="rId8" Target="metadata/systemRequirements.xml" Type="http://schemas.mathworks.com/matlab/addon/2014/relationships/systemRequirements"/>
</Relationships>'''

content_types_xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default ContentType="text/html" Extension="html"/>
  <Default ContentType="text/plain;charset=utf-8" Extension="m"/>
  <Default ContentType="application/vnd.mathworks.matlab.filesystemDefault" Extension="md"/>
  <Default ContentType="application/vnd.mathworks.matlab.filesystemDefault" Extension="mex"/>
  <Default ContentType="application/vnd.mathworks.matlab.filesystemDefault" Extension="p"/>
  <Default ContentType="image/png" Extension="png"/>
  <Default ContentType="application/pdf" Extension="pdf"/>
  <Default ContentType="application/json" Extension="json"/>
  <Default ContentType="text/csv" Extension="csv"/>
  <Default ContentType="application/vnd.openxmlformats-package.relationships+xml" Extension="rels"/>
  <Default ContentType="application/vnd.mathworks.matlab.addon.properties+xml" Extension="xml"/>
  <Override ContentType="application/xml" PartName="/fsroot/doc/helptoc.xml"/>
  <Override ContentType="application/xml" PartName="/fsroot/info.xml"/>
  <Override ContentType="application/vnd.mathworks.matlab.addon.configuration+xml" PartName="/metadata/configuration.xml"/>
  <Override ContentType="application/vnd.openxmlformats-package.core-properties+xml" PartName="/metadata/coreProperties.xml"/>
  <Override ContentType="application/vnd.mathworks.package.filesystemManifest+xml" PartName="/metadata/filesystemManifest.xml"/>
  <Override ContentType="application/vnd.mathworks.package.coreProperties+xml" PartName="/metadata/mwcoreProperties.xml"/>
  <Override ContentType="application/vnd.mathworks.package.corePropertiesExtension+xml" PartName="/metadata/mwcorePropertiesExtension.xml"/>
  <Override ContentType="application/vnd.mathworks.matlab.addon.systemRequirements+xml" PartName="/metadata/systemRequirements.xml"/>
</Types>'''

# Write to ZIP
with zipfile.ZipFile(OUTPUT_MLTBX, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types_xml)
    z.writestr("_rels/.rels", rels_xml)
    z.writestr("metadata/addonProperties.xml", addon_props_xml)
    z.writestr("metadata/configuration.xml", configuration_xml)
    z.writestr("metadata/coreProperties.xml", core_properties_xml)
    z.writestr("metadata/filesystemManifest.xml", manifest_xml)
    z.writestr("metadata/mwcoreProperties.xml", mwcore_xml)
    z.writestr("metadata/mwcorePropertiesExtension.xml", mwcore_ext_xml)
    z.writestr("metadata/systemRequirements.xml", system_req_xml)
    
    # Primary screenshot
    logo_path = os.path.join(REPO_DIR, "petrolaplace_logo.png")
    with open(logo_path, "rb") as f:
        z.writestr("metadata/primaryScreenShot.png", f.read())
        
    # fsroot files
    for local_path, rel_in_fs in file_list:
        arcname = "fsroot" + rel_in_fs
        with open(local_path, "rb") as f:
            z.writestr(arcname, f.read())

print(f"SUCCESS! PetroLaplace.mltbx created: {os.path.getsize(OUTPUT_MLTBX)} bytes ({os.path.getsize(OUTPUT_MLTBX)/(1024*1024):.2f} MB)")
