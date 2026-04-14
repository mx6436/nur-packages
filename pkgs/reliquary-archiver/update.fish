#!/usr/bin/env -S nix shell nixpkgs#fish nixpkgs#nix nixpkgs#jq --command fish

set game_data_repo Dimbreath/turnbasedgamedata

echo "--- Fetching latest revisions ---"
set game_data_rev (curl -fsS "https://gitlab.com/api/v4/projects/"(string replace '/' '%2F' $game_data_repo)"/repository/branches/main" | jq -er .commit.id)
if test $status -ne 0 -o -z "$game_data_rev" -o "$game_data_rev" = null
    echo "ERROR: Failed to fetch game data revision from $game_data_repo"
    exit 1
end

# 定义需要获取的游戏数据文件列表
set game_files \
    AvatarConfig.json AvatarConfigLD.json EquipmentConfig.json \
    RelicSetConfig.json ItemConfig.json AvatarSkillTreeConfig.json \
    AvatarSkillTreeConfigLD.json MultiplePathAvatarConfig.json \
    RelicConfig.json RelicMainAffixConfig.json RelicSubAffixConfig.json

# 初始化 manifest JSON 数据
set manifest_data (jq -n \
    --arg g_rev "$game_data_rev" \
    '{gameDataRev: $g_rev, files: {}}')

echo "--- Calculating hashes ---"

# 处理游戏数据文件
for file in $game_files
    set -l url "https://gitlab.com/Dimbreath/turnbasedgamedata/-/raw/$game_data_rev/ExcelOutput/$file"
    echo "Processing: $file"
    set -l nix_hash (nix-prefetch-url "$url" --type sha256 2>/dev/null)
    if test $status -ne 0 -o -z "$nix_hash"
        echo "ERROR: Failed to prefetch $file"
        exit 1
    end

    set -l hash (echo $nix_hash | xargs nix hash convert --to sri --hash-algo sha256)
    if test $status -ne 0 -o -z "$hash"
        echo "ERROR: Failed to convert hash for $file"
        exit 1
    end

    set manifest_data (echo $manifest_data | jq --arg f "$file" --arg h "$hash" '.files += {($f): $h}')
    if test $status -ne 0
        echo "ERROR: Failed to update manifest data for $file"
        exit 1
    end
end

# 处理 TextMapEN.json
echo "Processing: TextMapEN.json"
set -l tm_url "https://gitlab.com/Dimbreath/turnbasedgamedata/-/raw/$game_data_rev/TextMap/TextMapEN.json"
set -l tm_nix_hash (nix-prefetch-url "$tm_url" --type sha256 2>/dev/null)
if test $status -ne 0 -o -z "$tm_nix_hash"
    echo "ERROR: Failed to prefetch TextMapEN.json"
    exit 1
end

set -l tm_hash (echo $tm_nix_hash | xargs nix hash convert --to sri --hash-algo sha256)
if test $status -ne 0 -o -z "$tm_hash"
    echo "ERROR: Failed to convert hash for TextMapEN.json"
    exit 1
end

set manifest_data (echo $manifest_data | jq --arg h "$tm_hash" '.files += {"TextMapEN.json": $h}')
if test $status -ne 0
    echo "ERROR: Failed to update manifest data for TextMapEN.json"
    exit 1
end

# 检查 files 是否有变化
echo "--- Checking for meaningful changes ---"
set manifest_file "pkgs/reliquary-archiver/manifest.json"

set has_changes 0
if test -f $manifest_file
    set old_files (jq -eS '.files' $manifest_file)
    if test $status -ne 0 -o -z "$old_files"
        echo "ERROR: Failed to parse files from $manifest_file"
        exit 1
    end

    set new_files (echo $manifest_data | jq -S '.files')
    if test $status -ne 0 -o -z "$new_files"
        echo "ERROR: Failed to extract files from generated manifest data"
        exit 1
    end

    if test "$old_files" != "$new_files"
        set has_changes 1
    end
else
    set has_changes 1
end

# 仅当有变化时才写入文件
if test $has_changes -eq 1
    echo $manifest_data | jq . >$manifest_file
    echo "--- Done! File hashes have been updated ---"
else
    echo "--- No meaningful changes in files ---"
end
