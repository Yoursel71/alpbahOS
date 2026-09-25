#!/usr/bin/env python3
"""ULTRAKILL Unity: Assets/ULTRAKILL için kararlı GUID'li .meta dosyaları, ULTRAKILL.unity sahnesi ve
içe aktarılabilir dist/ULTRAKILL.unitypackage üretir.

.unitypackage biçimi: tar.gz; her varlık için <guid>/asset (içerik), <guid>/asset.meta, <guid>/pathname.
Kullanım: python3 tools/make_unitypackage.py
"""
import hashlib, io, os, tarfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'Assets')
PKG_DIR = os.path.join(ASSETS, 'ULTRAKILL')
OUT = os.path.join(ROOT, 'dist', 'ULTRAKILL.unitypackage')


def guid_for(rel):
    return hashlib.md5(('ultrakill-unity:' + rel).encode()).hexdigest()


def meta_text(rel, guid, is_dir):
    ext = os.path.splitext(rel)[1].lower()
    head = f'fileFormatVersion: 2\nguid: {guid}\n'
    tail = '  userData: \n  assetBundleName: \n  assetBundleVariant: \n'
    if is_dir:
        return head + 'folderAsset: yes\nDefaultImporter:\n  externalObjects: {}\n' + tail
    if ext == '.cs':
        return head + ('MonoImporter:\n  externalObjects: {}\n  serializedVersion: 2\n  defaultReferences: []\n'
                       '  executionOrder: 0\n  icon: {instanceID: 0}\n') + tail
    if ext == '.asmdef':
        return head + 'AssemblyDefinitionImporter:\n  externalObjects: {}\n' + tail
    if ext == '.shader':
        return head + ('ShaderImporter:\n  externalObjects: {}\n  defaultTextures: []\n  nonModifiableTextures: []\n'
                       '  preprocessorOverride: 0\n') + tail
    if ext in ('.md', '.txt', '.json'):
        return head + 'TextScriptImporter:\n  externalObjects: {}\n' + tail
    return head + 'DefaultImporter:\n  externalObjects: {}\n' + tail


SCENE = """%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!29 &1
OcclusionCullingSettings:
  m_ObjectHideFlags: 0
  serializedVersion: 2
  m_OcclusionBakeSettings:
    smallestOccluder: 5
    smallestHole: 0.25
    backfaceThreshold: 100
  m_SceneGUID: 00000000000000000000000000000000
  m_OcclusionCullingData: {{fileID: 0}}
--- !u!104 &2
RenderSettings:
  m_ObjectHideFlags: 0
  serializedVersion: 9
  m_Fog: 1
  m_FogColor: {{r: 0.12, g: 0.04, b: 0.035, a: 1}}
  m_FogMode: 1
  m_FogDensity: 0.01
  m_LinearFogStart: 25
  m_LinearFogEnd: 170
  m_AmbientSkyColor: {{r: 0.36, g: 0.26, b: 0.24, a: 1}}
  m_AmbientEquatorColor: {{r: 0.36, g: 0.26, b: 0.24, a: 1}}
  m_AmbientGroundColor: {{r: 0.36, g: 0.26, b: 0.24, a: 1}}
  m_AmbientIntensity: 1
  m_AmbientMode: 3
  m_SkyboxMaterial: {{fileID: 0}}
  m_Sun: {{fileID: 0}}
--- !u!157 &3
LightmapSettings:
  m_ObjectHideFlags: 0
  serializedVersion: 12
  m_GIWorkflowMode: 1
  m_GISettings:
    serializedVersion: 2
    m_BounceScale: 1
    m_IndirectOutputScale: 1
    m_AlbedoBoost: 1
    m_EnvironmentLightingMode: 0
    m_EnableBakedLightmaps: 0
    m_EnableRealtimeLightmaps: 0
  m_LightingDataAsset: {{fileID: 0}}
  m_LightingSettings: {{fileID: 0}}
--- !u!1 &1000
GameObject:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  serializedVersion: 6
  m_Component:
  - component: {{fileID: 1001}}
  - component: {{fileID: 1002}}
  m_Layer: 0
  m_Name: ULTRAKILL
  m_TagString: Untagged
  m_Icon: {{fileID: 0}}
  m_NavMeshLayer: 0
  m_StaticEditorFlags: 0
  m_IsActive: 1
--- !u!4 &1001
Transform:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  m_GameObject: {{fileID: 1000}}
  serializedVersion: 2
  m_LocalRotation: {{x: 0, y: 0, z: 0, w: 1}}
  m_LocalPosition: {{x: 0, y: 0, z: 0}}
  m_LocalScale: {{x: 1, y: 1, z: 1}}
  m_ConstrainProportionsScale: 0
  m_Children: []
  m_Father: {{fileID: 0}}
  m_LocalEulerAnglesHint: {{x: 0, y: 0, z: 0}}
--- !u!114 &1002
MonoBehaviour:
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {{fileID: 0}}
  m_PrefabInstance: {{fileID: 0}}
  m_PrefabAsset: {{fileID: 0}}
  m_GameObject: {{fileID: 1000}}
  m_Enabled: 1
  m_EditorHideFlags: 0
  m_Script: {{fileID: 11500000, guid: {game_guid}, type: 3}}
  m_Name: 
  m_EditorClassIdentifier: 
"""


def main():
    game_rel = 'Assets/ULTRAKILL/Scripts/UKGame.cs'
    scene_path = os.path.join(PKG_DIR, 'ULTRAKILL.unity')
    with open(scene_path, 'w', newline='\n') as f:
        f.write(SCENE.format(game_guid=guid_for(game_rel)))

    entries = []  # (rel, abs, is_dir)
    entries.append(('Assets/ULTRAKILL', PKG_DIR, True))
    for dirpath, dirnames, filenames in os.walk(PKG_DIR):
        dirnames.sort()
        for d in dirnames:
            ab = os.path.join(dirpath, d)
            entries.append((os.path.relpath(ab, ROOT).replace(os.sep, '/'), ab, True))
        for fn in sorted(filenames):
            if fn.endswith('.meta'):
                continue
            ab = os.path.join(dirpath, fn)
            entries.append((os.path.relpath(ab, ROOT).replace(os.sep, '/'), ab, False))

    # .meta dosyalarını depoda da tut (sahnedeki betik başvurusu bu GUID'lere dayanır)
    for rel, ab, is_dir in entries:
        g = guid_for(rel)
        meta = meta_text(rel, g, is_dir)
        with open(ab + '.meta', 'w', newline='\n') as f:
            f.write(meta)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    now = int(time.time())

    def add(tar, name, data):
        ti = tarfile.TarInfo(name)
        ti.size = len(data)
        ti.mtime = now
        ti.mode = 0o644
        tar.addfile(ti, io.BytesIO(data))

    with tarfile.open(OUT, 'w:gz') as tar:
        for rel, ab, is_dir in entries:
            g = guid_for(rel)
            with open(ab + '.meta', 'rb') as f:
                add(tar, f'{g}/asset.meta', f.read())
            add(tar, f'{g}/pathname', rel.encode())
            if not is_dir:
                with open(ab, 'rb') as f:
                    add(tar, f'{g}/asset', f.read())
    print(f'{OUT}: {len(entries)} varlık, {os.path.getsize(OUT)} bayt')


if __name__ == '__main__':
    main()
