"""Read-only identity/source audit for the native LFS 12.4-systemd package set.

This is an inventory prerequisite, not an executable recipe plan.  It cannot
launch a build or infer ownership from the staged package manifests.
"""
import hashlib
import json
import re
from pathlib import Path
from package_stage import validate_recipe

INVENTORY = Path(__file__).resolve().parents[2] / 'manifests/lfs-base-12.4-systemd.json'
EXPECTED_COUNT = 79
SCHEMA = 'alpbahOS.lfs-base-inventory/v1'
EXECUTION_STATUS = 'recipe coverage is partial; full stage runner and acceptance are incomplete'
ORIGIN_SHA256 = '612f7d8bdf54f228910c877b3a0c5d3565ead067c030ab55f9a0df472428fff5'
ORIGIN_PATH = 'docs/verification/manifests/lfs-base/m04-expected-chapter8-packages-12.4.json'
SOURCE_ALIASES = {'libelf': 'elfutils'}
BOOK_XML_FILES = {'procps-ng': 'procps'}
BOOK_COMMIT = 'd7bc803361f445a649d0ca0832219f75b6e68683'
BOOK_REPOSITORY = 'https://git.linuxfromscratch.org/lfs.git'
BOOK_XML_SHA256 = {
    'gcc': '473f1b6097fe51655d02ac9660d0e9b67d620e35d628e50f3c0925df8becfeff',
    'glibc': '2e0963fd6ac1a86b623037f1fb778989ba8ec5eba281bf88074a8740e63c9830',
    'groff': '3faac14b11858336ade409419f8d89ff3abf6483eee8f30881c0b27a57fb81bb',
    'iproute2': '3011c983412f13c79fdd0290496c3fc8208a423e7051b105829b0320187d1b7b',
    'bzip2': 'fb2e8994a7c222e04aad253a0dccd812b21d01df584dad3653babb6cb69763f9',
    'file': '9547a82e9d4bf3c4e174dedc70a5b64a7d949fa06bc092bf6bba3f18ebb6c118',
    'iana-etc': 'ad05cf83853b61fb6ee8cef86e435a02f261e8cdaf976cbeb1519871cdc2a39f',
    'bc': 'b1ff66ff058a42331d9deb2a8544eb94c13d636809302f94c3d1adfa9776ca5c',
    'flex': '74902ad3f6ede79e9c922c62279606809defff4ba9dcbb36ab59338d4a170d1f',
    'lz4': '40d9a35c11bff73d937505df2ab529142718620d10711cfc2bf31f30e531ee2c',
    'm4': '32d33704233478a59122bf3ef4e26df52719628e0be85111734be4e7562e6980',
    'man-pages': '129bbfcb946e2c278a6cdb6777784610a16cf08ddde31679d3f0834d447ebbbe',
    'pkgconf': '4eeb2adce2209539f4d11a81ab28a836b309c00c2cc62ccfa2196fead2f1822d',
    'sed': '247084eca3813fbd5bbea83ee5c428095492454db6da729fdd51fd76fdf6db0d',
    'psmisc': '0215f2f0c3f6d072bbb6f09fba15e202d88d95be17285f0cd25bee3efbe0f050',
    'bison': '2e1ac9537f49a695412af3dcdb519c74b8c9cd1a62b7594520e597460e755adc',
    'grep': '2b34b616fcb1b6daacd058c989f065fc84554a7334415da8db24302366b83d07',
    'gzip': '2b2042309aa395625848d21dd6e4a5dc601377e598a9c7f6252de0f48d1c1bab',
    'diffutils': '0588df1d7caaa780e795e0995374d6c69b50fae952e261dcbbb76b5bc323d15d',
    'patch': '1414d82eaf9a794442e714fcecdfb383b6285a63c6ec0ab5de9d6279b419aa99',
    'tar': 'fc13763ecd1f9d190ed28d6ee8cdd7d4b40febe0f7a5c1f6d884bfbafb98ca87',
    'less': 'cb7969087b56e47d2b5f583f86176689b74083062dd9f95220526042259ec351',
    'make': '2c95795d631a2d1132ee1148d45623f61e67d5be7b7645e3fa9804f2b8e2e6cc',
    'gdbm': '1951a1a97c5fcb87583799e20a0f94169ae5cec5cbe143353278387438b0ad63',
    'expat': 'dc7434cf31175b066f4934c69e7dc681d6a14d551e521d75c65b9d668c7efc80',
    'gperf': '3f94e42a739349238a3122816c633e1bb0393b364900becbd560132e02b6a2dd',
    'libpipeline': 'bdd9c934c2af50aed9b8c065f65d803a61bc4c065abaee1d9088d88e97ed09b5',
    'attr': '5036c778eaefd8d10cc37e8e034fff2379cd7fed4134e706520068d37088abe8',
    'acl': 'd81756a4f6e8338990760a903007695fdcb32d5e728e4d076c8ab201fd399fdf',
    'readline': '1e84ab230949c98774ee46e36c293ed1e2005ba421f212d027694169190c5b87',
    'libcap': 'a822f0c39c0d8968f5d025122659ae320ffa14645eaccd6cd04195f3364ee7e5',
    'gawk': 'e0062e57c65d3ed85039196398d9ae66f6efb212f525666ac841dce33bcb2158',
    'tcl': 'c812fbf3967181391de1972f8a2fa60180506446d34e2f4080df0448356f0261',
    'expect': '1349dc6f453ef7bab820baf3d76008191706b820af4ecac3121406165ee8c92a',
    'dejagnu': '1e55fa29f3e82b4284fd031ac603e3d1ccfef7e51529ff80947efcc1e058afd9',
    'intltool': 'c21c20b8ca96bba6d4d35e68aa2fd0e5a084d820406f135ef6117b15ca5ff000',
    'autoconf': '8b0cb59f65183dea443bd1b7c30d93a286fe276bd561678cca8c1954a47e2f69',
    'automake': 'd8586f82dd44aaf0047337358d96670e8f83130564163fed939f2c554f27ae49',
    'bash': '9fe070f789e379dec2a68a64e5dfc06a6eb7d236f534d9c530b90d75bc7e97e6',
    'libxcrypt': 'e87ee8f037b65e6750471cd79b526b3472e0e5671d28abd37ce54cd07ef64508',
    'findutils': '79a63af0e9f451fac785e05e31704acf63ea0abe3eb34315ed59a36fce129c81',
    'libtool': 'ecc927f6a58776dac826084985251e432bd555daf052d3299e3b6fae26777f48',
    'kbd': 'c2e999d52dd892ab94009ff16460ed9e3e360fc6066481a2b25e15f41443c2f3',
    'texinfo': '2cc17df2007db70ea92c5bc1ec41926e283a308ea32e49b4346c6a248a54f402',
    'inetutils': '3a87a7886dcc4e77f0fd98eb62538c8262145193c77767f17da43f5ed209d557',
    'procps-ng': 'bdc79f62082ae28313c36984b94e7df876eee9b9e5f115db01cd3c68598718be',
    'man-db': 'e26ffab920031a9c60903a24e7eb909097cb0668295513ae0ea36b45da0a2082',
    'vim': 'cfd7f15689d106815f1de0f3dbb9e9ce2f7920261758ac9fc69916790dee355a',
    'gmp': 'e4fc414286796dad7305a71e4f132581c7ebf7f752a521501e6f5685e592a99f',
    'mpfr': '7049ee35134aad6c65a45aa1c37230c9babcc98486e35018695b7f96dca110c1',
    'mpc': '834f91363019500cd17c90ce96775e306c776b4b8b244e080f548859f10badc9',
    'flit-core': '8546fa0b43f78b1389eb609ff5436fd6f7f423ebdf07bcd21fbc938edb923c80',
    'packaging': '6721380541260fec3379ad058163e7bca96c5923a33f8941d11e271dd468ebc8',
    'wheel': '141f894c1da159876c3a29edd0f62bf1ad2933e080caca09a79466628f60c703',
    'setuptools': 'c9a329047969372da2ad26fa185cf1f498cde4aa5ed28a9f9e79cbe13a758335',
    'ninja': '814de6fa2add46faa020bab47bcc252c6dc4a68215dcbe88a69bff91fae60ff1',
    'meson': 'a768b33fd7fc82fd2732f71b29264c188810851457d48aeb92ae7defc1fbab49',
    'markupsafe': 'd41423fe913aad821e79f3b7d8e4a06711f1e0190e0ac7750bb270e4d2d54a29',
    'jinja2': 'c7e46c1d2dc4f3c7d1dd359443a0515cf7c53112f67b77d4fdaeee8a988e9480',
    'openssl': 'c32bd9094750ae4d4e4d66c50392f337510a6b337f0e7bca011328af86ed617f',
    'libffi': '78028564e6ea66f37394b43d9d9d3a86616c92999ad9194e2f2637b533b85def',
    'xml-parser': '5cf31be76d0d56071f58807c8c64bf3d39b50628e48034e5a0bf8a73f9666b9f',
    'kmod': '35922ba69fdb5aa0a819e2421e13f05252630e6b1d196842a1621ed16fbc452b',
    'xz': '31fa6c64386f262461a42060d36f95e0d790d4cb381790b6c729f60f2860be8e',
    'zlib': 'a2fd783b5e821e5cf2e35630b4d6e70e22021bfc6e6308d50695a9c4506e3b8b',
    'zstd': 'd74d1341d8531397f54368630e97c6c0c3423eb65eef5e67c44aabd17bcc9500',
    'gettext': '504582539416fefe310cdeb8e4f8f3546434ca4aca8964bf10485ca2272c3a63',
    'libelf': '70530e57829039ad80ed021961cdfa7e7dce06fbe8ff5d278f50af3207222dd1',
    'grub': 'a216f0354b18a18cbf7d7a6f4b1da4a4106dc742a53b51f3443c09bd0e67a2bf',
    'dbus': '8524e683bacad2927ae84529fdf4d3b2954756b1109329b9fc352a1075d29794',
    'e2fsprogs': 'd6679ee5a924a097041ee388b7de7b855798312189d35795efdc49addaae3800',
    'shadow': '1d36f34d5fdc48a9465e75ee5f3034024fde7ee299f0e1d9ada7f8c40019347a',
    'perl': '2a7ec6751e8cb85733922bd0ec2e0472dc0dfed1662fc912df6b8e262ab0b00c',
    'python': '1c9628e3c18861adbb53717c56a7eb81b50e6cf6684082f9490a65a598700dbe',
    'ncurses': 'eec73bf89c269fc666f6619a42d82ec563108b3e9990b0757b122d2f4b1a9986',
    'systemd': '7f09c46a8200e71261f74cb64ffbfa2ab5c2c164c3153dec72492afaa037354a',
    'coreutils': 'b2ecac2f8dfc1ebc716ff6f91f01f6e78521c6d2243cb9b1df02bdd1786ed541',
    'util-linux': 'd0a6aad684bf6ea1dd2fcc6fe4a611ec923db8b643c5d7098858e9bed9547008',
    'binutils': 'ff9e545c5c54617e3433dfd8f5392ffcecfdafc15b1ae1ca8725a48212a4168d',
}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def load(repo=None):
    repo = Path(repo or INVENTORY.parents[1])
    inventory_path = repo / 'manifests/lfs-base-12.4-systemd.json'
    sources_path = repo / 'manifests/infra-sources.json'
    for path in (inventory_path, sources_path):
        if path.is_symlink() or path.resolve() != path or not path.is_file():
            raise RuntimeError('Unsafe/missing LFS base inventory input')
    inventory_raw, source_raw = inventory_path.read_bytes(), sources_path.read_bytes()
    inventory, manifest = json.loads(inventory_raw), json.loads(source_raw)
    rows = inventory.get('packages')
    if (inventory.get('schema') != SCHEMA or inventory.get('book') != 'LFS 12.4-systemd Chapter 8'
            or inventory.get('count') != EXPECTED_COUNT or not isinstance(rows, list)
            or len(rows) != EXPECTED_COUNT or inventory.get('execution_status') != EXECUTION_STATUS):
        raise RuntimeError('LFS native package inventory schema/count/status invalid')
    origin = inventory.get('inventory_origin')
    if (inventory.get('source_manifest_sha256') != digest(source_raw)
            or not isinstance(origin, dict) or origin.get('path') != ORIGIN_PATH
            or origin.get('sha256') != ORIGIN_SHA256):
        raise RuntimeError('LFS package inventory provenance/source pin changed')
    sources = manifest.get('sources')
    if not isinstance(sources, list):
        raise RuntimeError('Pinned LFS source manifest is malformed')
    by_id = {}
    for source in sources:
        identity = source.get('id')
        if not isinstance(identity, str) or identity in by_id:
            raise RuntimeError('Duplicate/malformed source id')
        if (source.get('filename') != identity or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+\-]*', identity)
                or not re.fullmatch('[0-9a-f]{64}', source.get('sha256', ''))
                or type(source.get('size')) is not int or source['size'] <= 0
                or not isinstance(source.get('url'), str) or not source['url'].startswith('https://')):
            raise RuntimeError('LFS source pin invalid: ' + identity)
        by_id[identity] = source
    output, names, used_sources = [], set(), set()
    for number, row in enumerate(rows, 1):
        if (not isinstance(row, dict) or row.get('order') != number
                or not isinstance(row.get('name'), str) or not re.fullmatch('[a-z0-9][a-z0-9-]*', row['name'])
                or row['name'] in names or not isinstance(row.get('version'), str)
                or not re.fullmatch(r'[0-9][A-Za-z0-9.+_-]*', row['version'])
                or not isinstance(row.get('recipe'), str)):
            raise RuntimeError('LFS package order/identity/recipe state invalid at row ' + str(number))
        source_id = row.get('source_id')
        if source_id not in by_id or source_id in used_sources:
            raise RuntimeError('Missing/reused LFS package source pin: ' + str(source_id))
        source = by_id[source_id]
        prefix = re.sub('[^a-z0-9]', '', SOURCE_ALIASES.get(row['name'], row['name']).lower())
        source_stem = re.sub('[^a-z0-9]', '', source_id.lower().split('.tar')[0])
        version = re.sub('[^a-z0-9]', '', row['version'].lower())
        if not source_stem.startswith(prefix) or version not in source_stem[len(prefix):]:
            raise RuntimeError('LFS package version absent from pinned source filename: ' + row['name'])
        auxiliary_ids = row.get('auxiliary_source_ids')
        if (not isinstance(auxiliary_ids, list) or any(not isinstance(v, str) or v not in by_id for v in auxiliary_ids)
                or len(set(auxiliary_ids)) != len(auxiliary_ids) or source_id in auxiliary_ids):
            raise RuntimeError('LFS auxiliary source references invalid: ' + row['name'])
        names.add(row['name']); used_sources.add(source_id)
        resolved = {**row, 'source': source,
                    'auxiliary_sources': [by_id[source_id] for source_id in auxiliary_ids]}
        if row['recipe'] != 'pending':
            expected_path = f'recipes/base/{row["name"]}.json'
            recipe_path = repo / row['recipe']
            if (row['recipe'] != expected_path or recipe_path.is_symlink() or recipe_path.resolve() != recipe_path
                    or not recipe_path.is_file()):
                raise RuntimeError('LFS base recipe path invalid: ' + row['name'])
            recipe = json.loads(recipe_path.read_bytes())
            requirements = recipe.get('requires', [])
            patches = recipe.get('patches', [])
            prerequisites = recipe.get('prerequisites', [])
            basis = recipe.get('basis')
            basis_valid = (isinstance(basis, dict)
                and basis.get('architecture') == 'ml_32'
                and basis.get('book') in ('LFS-12.4-systemd', 'MLFS ml-12.4 m32-systemd')
                and basis.get('commit') == BOOK_COMMIT
                and basis.get('file') == f'chapter08/{BOOK_XML_FILES.get(row["name"], row["name"])}.xml'
                and basis.get('repository') == BOOK_REPOSITORY
                and basis.get('sha256') == BOOK_XML_SHA256.get(row['name'])
                and basis.get('tag') == 'ml-12.4')
            if (recipe.get('schema') != 'alpbahOS.recipe/v1' or recipe.get('name') != row['name']
                    or recipe.get('version') != row['version'] or recipe.get('source') != source_id
                    or recipe.get('phase') != 'base' or recipe.get('abi') != manifest.get('abi_selection', {}).get('mode')
                    or recipe.get('requires_oc_and_abi_authorization') is not True
                    or recipe.get('requires_stability_receipt') is not True
                    or not basis_valid
                    or not isinstance(requirements, list)
                    or any(not isinstance(dependency, str) for dependency in requirements)
                    or len(set(requirements)) != len(requirements)
                    or any(dependency not in names for dependency in requirements)
                    or not isinstance(patches, list)
                    or any(not isinstance(item, dict) or item.get('source') not in auxiliary_ids for item in patches)
                    or not isinstance(prerequisites, list)
                    or any(not isinstance(item, dict) or item.get('source') not in auxiliary_ids
                           for item in prerequisites)):
                raise RuntimeError('LFS base recipe/package/source/authorization binding invalid: ' + row['name'])
            validate_recipe(recipe, recipe.get('jobs'))
            resolved['recipe_data'] = recipe
        output.append(resolved)
    if (inventory.get('count') != len(names) or len(used_sources) != EXPECTED_COUNT
            or inventory_raw != (json.dumps(inventory, indent=2, sort_keys=True) + '\n').encode()):
        raise RuntimeError('LFS package inventory is noncanonical or incomplete')
    return output
