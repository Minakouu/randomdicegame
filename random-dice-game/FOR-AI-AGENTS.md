# FOR-AI-AGENTS.md

Bu dosya, bu projede çalışacak AI ajanları (Claude Code, Cursor vb.) için teknik rehberdir.
İnsan için içerik ekleme rehberi `README.md`'dedir. Önce bu dosyayı, sonra gerekirse README'yi oku.

## 1. Proje nedir

"Random Ass Dice Game": Godot 4.3, GDScript, 2D, menü tabanlı, D&D'den esinlenmiş roguelike zar oyunu.
Hareket/platform yok. Tüm UI kodla kurulur (`main.tscn` boş bir `Control`).
Orijinal tasarım belgesi: `~/Desktop/dice_dungeon_proje.md` (Türkçe). Kullanıcıyla Türkçe, kısa ve samimi konuş.

**Durum:** Kod yazıldı ama Godot kurulu olmadığı için **hiç çalıştırılmadı**. Yazım/çalışma hatası olabilir.
Godot'a erişimin varsa ilk iş: `godot --headless --path . --check-only` (veya `--quit` ile aç) ve Output'taki hataları temizle.

## 2. Oyun kuralları (kodun uyduğu tasarım)

1. Oyuncu: 20 can, 20 stamina, standart silah/zırh, 2 iksir, 0 altın (hepsi `data/player.json`).
2. Zar 1 = dungeon (stage sayısı kadar yüzlü). Zar 2 = zorluk 1-6:
   1-2 `crowd` (sürü, tek can havuzu), 3-4 `elite`, 5-6 `boss`.
3. Enter veya Flee. Flee = stamina düşer (`flee_cost`); stamina yetmezse Flee kapalı.
4. Dungeon bitince: altın, `stamina_rest_base − zorluk` stamina, `hp_regen` can. Boss kesilirse item düşer.
5. Her `shop_every` (5) dungeon'da mağaza: rastgele 4 satılık item + iksir.
6. Combat: oyuncu her zaman ilk. Saldırı = Σ((D20 + silah_bonusu) × silah_çarpanı) (her zara bonus ayrı, `dice_count` zar).
   Savunma = (D10 + zırh_bonusu + defense_bonus efekti) × zırh_çarpanı. `net = saldırı − savunma`, `net ≤ 0` → dodge/savuşturma.
   Yuvarlama toplam üzerinde tek yerde (`int(round())`).
7. Ölünce her şey sıfırlanır (`GameState.reset()`).
8. 6 boss'un hepsi kesilince "Boss Yolu" butonu açılır: `player.json` → `final_boss`. Kesilince oyun biter.
9. Zorluk ölçekleri: kademe içi (zorluk 2/4/6) hp ×1.2, hasar ×1.1; run ilerledikçe `depth_hp`/`depth_dmg` (her dungeon'da %4 / %2).

## 3. Dosya haritası

```
project.godot                 autoload: GameState; ana sahne scenes/main.tscn; nearest texture filter
scenes/main.tscn              Control + game_manager.gd
scripts/game_state.gd         AUTOLOAD. Oyuncu durumu, ekipman, efekt toplama, reset
scripts/game_manager.gd       Akış, UI kurulumu, combat, zar animasyonu, mağaza, efektler (tween)
scripts/data_db.gd            JSON yükleyici + erişim fonksiyonları (static)
scripts/resources/*.gd        ItemData, EnemyData, DungeonData (düz Resource, class_name YOK)
data/items.json enemies.json dungeons.json player.json     TÜM içerik
assets/sprites/{items,enemies,dungeons,players}/<id>.png   id ile otomatik eşleşir
README.md                     İnsan için içerik ekleme rehberi
```

## 4. Mimari kararlar (ve nedenleri)

- **`class_name` kullanılmıyor.** Taze projede global class cache'e güvenmemek için scriptler `preload()` ile bağlanıyor
  (`const Db = preload("res://scripts/data_db.gd")`). Yeni script eklerken aynı yolu izle.
- **Resource alanları `@export` değil, düz `var`.** Veri `.tres`'ten değil JSON'dan yükleniyor; Inspector'da düzenlenmiyor.
- **Veri tipleri koşullu "untyped".** `Resource` tipli değişkenlerde alan erişimi (`item.bonus`) Variant döner.
  `var x := item.bonus * 2` gibi `:=` çıkarımı **parse hatası** verir → `var x: float = ...` veya `int(...)` kullan.
- **UI kodla kurulur** (`_build_ui`). `.tscn`'e elle node yazma; kırılgan.
- **State machine:** `enum S { ROLLING, DECISION, COMBAT, SHOP, DEAD }` (`game_manager.gd`). Görünür butonları `_refresh()` belirler.
  Durum değiştirince mutlaka `_refresh()` çağır.
- **`busy` bayrağı:** zar animasyonu ve düşman turu `await` kullanır; `busy` iken butonlar ve handler'lar yok sayılır.
  Yeni `await`'li akış eklersen `busy`'yi başta set et, her çıkış yolunda sıfırla (ölüm/kazanma dahil).
- **Efekt sistemi:** `GameState.effect("anahtar")` takılı 4 itemin (weapon/armor/rune/accessory) `effects[anahtar]` değerlerini toplar.
  Türetilmiş değerler `get_max_hp()`, `get_max_stamina()`, `get_flee_cost()`, `get_hp_regen()`. **Ham `base_*` değişkenleri doğrudan
  kullanma**, `get_*` kullan. Yeni efekt eklemek: (a) `item_data.gd` içindeki `EFFECT_NAMES`'e ad ekle, (b) etkisini ilgili yerde `effect("x")` ile uygula.
- **Düşman yetenekleri** `game_manager.gd` → `_enemy_turn()` / `_enemy_strike()`: `heal, regen, double_hit, pierce, enrage`.
  Yenisi için `ABILITY_TEXT`'e Türkçe ad + `_enemy_turn` içinde mantık ekle.
- **Sprite çözümü:** `Db.load_texture(explicit, klasör, id)`: önce `sprite` alanı, sonra `assets/sprites/<klasör>/<id>.png`.
  `ResourceLoader` (import edilmişse) → yoksa `Image.load_from_file` yedeği. Sprite yoksa `null`, UI çökmez.
- **Static değişkenler** (`Db.items` vb.) ilk erişimde `ensure_loaded()` ile doldurulur. JSON'u değiştirince oyunu yeniden başlat (hot reload yok).

## 5. İçerik ekleme (özet; ayrıntı README.md'de)

JSON'a kayıt ekle, id ile aynı adda png at. Doğrulamadan önce şunu kontrol et (id referansları):
- `dungeons.json` içindeki `crowd/elite/boss` → `enemies.json` id'leri
- `boss_drops`, `player.json` → `starting_weapon/starting_armor/final_drop` → `items.json` id'leri; `final_boss` → `enemies.json`
- Hatalı id'de `Db` `push_error` yazar ve o dungeon'u atlar (oyun çökmez).
- `type`: `weapon | armor | rune | accessory`. Rune/aksesuar için bonus/çarpan gerekmez.
- Silah/zırh boss drop'u: daha güçlüyse otomatik takılır (`GameState.score`). Rune/aksesuar: yalnızca slot boşsa. Mağazadan alınan her şey doğrudan takılır (eskisinin yerine).

## 6. Denge

Denge Python simülasyonuyla ayarlandı (basit bot: hep saldır, HP≤8'de iksir, boss'tan kaçma kuralı).
Son sonuç: ortalama ~8 dungeon, medyan 5, ilk dungeon'da ölüm ~%8, 20+ dungeon ~%9.
**Bu tahmindir, gerçek oyunla doğrulanmadı.** Sayıları değiştirirsen sadece JSON'daki hp/damage_mult/depth_* değerlerine dokun;
gerekirse simülasyonu yeniden yaz (fight() mantığı `game_manager.gd` combat ile birebir aynı olmalı: yuvarlama, savunma, yetenekler).

Mevcut ayarlar: sürüler dokunulmamış; elite/boss hp ×0.75 ve hasar ×0.85 uygulanmış; `dice_god` ayarsız.

## 7. Bilinen eksikler / yol haritası

Yapılmadı (öncelik sırasıyla önerilir):
1. **Çalıştırma/test** — hiç çalıştırılmadı. En büyük risk.
2. Çoklu karakter (`characters.json`), kalıcı unlock + kayıt (`user://save.json`).
3. Olay kartları (sandık, tuzak, sunak), envanter/ekipman yönetimi (şu an eski item kaybolur).
4. Ses/müzik, gerçek sprite'lar (mevcut olanlar Python ile üretilmiş basit placeholder'lar).
5. Boss Yolu'nu zincirli çoklu boss'a çevirmek (şu an tek `final_boss`).
6. Düşman sprite'ı olmayan `dice_god` için kendi çizimi (şu an lich_king kopyası).

## 8. Çalışma kuralları (bu proje için)

- Kullanıcı Türkçe konuşur; kısa, net cevap ver. Kullanıcı hakkında cinsiyet/zamir varsayma.
- Oyun mantığı kararlarını (kural değişikliği) kullanıcıya sor; sadece uygulama detaylarına kendin karar ver.
- Yeni özellik = önce JSON/veri odaklı düşün; kod değişikliği ancak yeni mekanik gerekiyorsa.
- Godot'a erişimin yoksa "çalıştı" deme; test edilmediğini açıkça söyle.
- Gereksiz yazılım kurma (ör. `brew install godot`) kullanıcıdan açık onay almadan yapma. Kullanıcı bir kez "şimdilik hayır" dedi.
- Kod stili: tab girinti, GDScript 4 tip ipuçları, fonksiyonlar kısa; Türkçe log/UI metinleri.
