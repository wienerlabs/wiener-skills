---
name: haftalik
description: Bütün projelerdeki (varsayılan ~/Documents/GitHub) son 7 günün commit'lerini toplayıp tek bir haftalık özet çıkarır. "Bu hafta ne yaptım", "haftalık özet" isteklerinde kullan.
argument-hint: "[gün=7] [--patron] [kök dizin]"
---

# /haftalik — haftalık özet

Argümanlar: $ARGUMENTS (`--patron`: teknik olmayan dil)

1. Topla: `${CLAUDE_SKILL_DIR}/../haftalik/scripts/topla.sh [gün] [kök]`
   Diff okuma; commit mesajları yeterli. Bir projede mesajlar anlamsızsa ("fix", "wip") sadece o projede birkaç commit için `git -C <proje> show --stat <hash>` bak.
2. Yaz:

```markdown
# Haftalık özet — <tarih aralığı>
<N> projede <M> commit.

**Öne çıkanlar**
- <haftanın en önemli 2-3 işi>

**<Proje adı>** (<commit sayısı>)
- <2-4 madde; benzer commit'leri birleştir, işin ne olduğunu söyle>

**Yarım kalanlar / sırada**
- <aktif dallardaki tamamlanmamış işler, commit mesajlarından anlaşılıyorsa>
```

- `--patron` ile: teknik terim, dal adı, commit hash'i yok; işin kullanıcıya/şirkete etkisi.
- Projeleri commit sayısına göre sırala. Bir-iki commit'lik projeleri sonda tek satırda topla.
3. Kaydet: `~/.local/state/claude-notlar/_haftalik/<YYYY>-H<hafta no>.md` (`mkdir -p`). Özeti sohbete de yaz.
