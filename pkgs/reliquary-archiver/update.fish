#!/usr/bin/env -S nix shell nixpkgs#fish nixpkgs#nix nixpkgs#jq --command fish

set game_data_repo "Dimbreath/turnbasedgamedata"

echo "--- Fetching latest revisions ---"
set game_data_rev (curl -s "https://gitlab.com/api/v4/projects/"(string replace '/' '%2F' $game_data_repo)"/repository/branches/main" | jq -r .commit.id)

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
    set -l hash (nix-prefetch-url "$url" --type sha256 2>/dev/null | xargs nix hash convert --to sri --hash-algo sha256)
    set manifest_data (echo $manifest_data | jq --arg f "$file" --arg h "$hash" '.files += {($f): $h}')
end

# 处理 TextMapEN.json
echo "Processing: TextMapEN.json"
set -l tm_url "https://gitlab.com/Dimbreath/turnbasedgamedata/-/raw/$game_data_rev/TextMap/TextMapEN.json"
set -l tm_hash (nix-prefetch-url "$tm_url" --type sha256 2>/dev/null | xargs nix hash convert --to sri --hash-algo sha256)
set manifest_data (echo $manifest_data | jq --arg h "$tm_hash" '.files += {"TextMapEN.json": $h}')

# 检查 files 是否有变化
echo "--- Checking for meaningful changes ---"
set manifest_file "pkgs/reliquary-archiver/manifest.json"

set has_changes 0
if test -f $manifest_file
    set old_files (cat $manifest_file | jq -S '.files')
    set new_files (echo $manifest_data | jq -S '.files')
    if test "$old_files" != "$new_files"
        set has_changes 1
    end
else
    set has_changes 1
end

# 仅当有变化时才写入文件
if test $has_changes -eq 1
    echo $manifest_data | jq . > $manifest_file
    echo "--- Done! File hashes have been updated ---"
else
    echo "--- No meaningful changes in files ---"
end
