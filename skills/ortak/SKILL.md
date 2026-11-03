---
name: ortak
description: Kişisel skill'lerin ortak yardımcı script'leri. Doğrudan çağrılmaz.
user-invocable: false
disable-model-invocation: true
---

Bu klasör /analiz, /devir, /devam, /uyku, /gunaydin, /rapor ve /haftalik'in paylaştığı script'leri tutar.

- `scripts/notlar-dizini.sh [alt-dizin]` — projenin not dizinini yazdırır (`~/.local/state/claude-notlar/<proje>-<hash>/`). Repo dışındadır ve aynı reponun bütün worktree'leri aynı dizini kullanır.
