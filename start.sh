#!/usr/bin/env bash
# Run from the exam workspace. No global configuration or existing file is changed.
set -euo pipefail

fail() { printf '설치 중단: %s\n' "$*" >&2; exit 1; }
for tool in codex cp diff mkdir; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool 명령이 없습니다. 제공 환경을 확인하세요."
done

kit=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
project=$(cd -- "${1:-$PWD}" && pwd -P) || fail '과제 폴더를 열 수 없습니다.'
[[ "$project" != / && "$project" != "$kit" ]] || fail '준비 저장소가 아닌 실제 과제 폴더에서 실행하세요.'
skills="$project/.agents/skills"
names=(hynix-triage hynix-build hynix-verify hynix-explain hynix-semiconductor)
[[ -f "$kit/AGENTS.md" ]] || fail '준비 저장소의 AGENTS.md가 없습니다.'

# Check every destination before creating anything in the workspace.
for dir in "$project/.agents" "$skills"; do
  [[ ! -L "$dir" ]] || fail "링크 경로를 변경하지 않습니다: $dir"
  [[ ! -e "$dir" || -d "$dir" ]] || fail "폴더가 아닌 기존 경로입니다: $dir"
done
for name in "${names[@]}"; do
  source_dir="$kit/.agents/skills/$name"
  destination="$skills/$name"
  [[ -f "$source_dir/SKILL.md" ]] || fail "스킬이 누락됐습니다: $name"
  [[ ! -L "$destination" ]] || fail "기존 스킬 링크를 변경하지 않습니다: $name"
  if [[ -e "$destination" ]]; then
    [[ -d "$destination" ]] || fail "같은 이름의 기존 파일이 있습니다: $name"
    diff -qr -- "$source_dir" "$destination" >/dev/null 2>&1 ||
      fail "기존 $name 내용이 다릅니다. 기존 파일을 보존했습니다."
  fi
done
[[ -f "$kit/.agents/skills/hynix-semiconductor/references/metrics.md" ]] ||
  fail '반도체 참고자료가 없습니다.'

mkdir -p -- "$skills"
for name in "${names[@]}"; do
  destination="$skills/$name"
  if [[ ! -e "$destination" ]]; then
    mkdir -- "$destination" || fail "스킬 폴더 생성 실패: $name"
    cp -R -n -- "$kit/.agents/skills/$name/." "$destination/"
  fi
  diff -qr -- "$kit/.agents/skills/$name" "$destination" >/dev/null 2>&1 ||
    fail "스킬 복사가 완료되지 않았습니다: $name"
done

if [[ ! -e "$project/AGENTS.md" && ! -L "$project/AGENTS.md" &&
      ! -e "$project/AGENTS.override.md" && ! -L "$project/AGENTS.override.md" ]]; then
  (set -o noclobber; cat -- "$kit/AGENTS.md" > "$project/AGENTS.md") ||
    fail 'AGENTS.md를 생성하지 못했습니다. 기존 파일은 덮어쓰지 않았습니다.'
  printf '새 AGENTS.md 추가 완료.\n'
else
  printf '기존 AGENTS.md / AGENTS.override.md 보존. 공통 지침은 첫 요청에 함께 전달합니다.\n'
fi

rules=$(<"$kit/AGENTS.md")
prompt="지금은 해커톤 키트 적용 단계다. 기존 과제 파일은 수정하지 말고 적용 상태만 짧게 확인해 줘.
현재 작업 폴더의 실제 과제 지침과 상위 AGENTS.md·AGENTS.override.md를 우선한다.
아래 공통 지침을 이 대화의 보조 규칙으로 적용하고, 충돌하면 기존 공식 과제 지침을 따른다.
스킬 5개는 현재 작업 폴더의 .agents/skills에 이미 배치돼 있다. 필요한 단계에만 해당 SKILL.md를 읽어 사용한다.
지침이나 스킬을 다시 설치·복사하거나 기존 파일을 편집하지 않는다. 모델·권한·전역 설정도 변경하지 않는다.
적용한 작업 경로와 사용 가능한 스킬을 짧게 알리고 사용자의 과제 요청을 기다려 줘.

<hackathon_guidance>
$rules
</hackathon_guidance>"

printf '스킬 5개 적용 완료. 과제 폴더: %s\nCodex를 시작합니다.\n' "$project"
exec codex -C "$project" "$prompt"
