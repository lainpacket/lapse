--!nocheck
--[[
	Neverlose Reloaded UI
	A single-file Roblox recreation of https://github.com/kdt255/Neverlose-Reloaded (Dear ImGui).
	No uploaded images are required: every icon is rasterised in code from embedded outlines.

	Quick start:

		local Library = loadstring(source)()      -- or require() it as a ModuleScript
		local Window = Library:CreateWindow({
			Folder = "MyMenu",
			Title = "My UI",
			Subtitle = "Settings",
			Account = { Name = "Player", Status = "Local profile" },
		})
		local Tab = Window:Tab({ Name = "Main", Icon = "SLIDERS_H" })
		Tab:Box({ Name = "Settings", Column = 1 }):Toggle({ Name = "Enabled" })
		Window:Finish()

	The library does not create a window automatically. Call Library:Demo() explicitly to build
	the demo. RightShift hides a window by default.

	Building your own:

		local Window = Library:CreateWindow({ ToggleKey = Enum.KeyCode.RightShift, Folder = "MyMenu" })
		Window:Group("AIMBOT")
		local Rage = Window:Tab({ Name = "Rage", Icon = "CROSSHAIRS" })
		local Main = Rage:Box({ Name = "MAIN", Column = 1 })          -- Column 1 or 2
		Main:Toggle({ Name = "Enabled", Default = true, Callback = print })
		Main:Slider({ Name = "Field Of View", Min = 0, Max = 180, Default = 90 })
		Main:Combo({ Name = "Mode", Options = { "One", "Two" } })
		Main:Multi({ Name = "Parts", Options = { "Head", "Chest" }, Default = { true, false } })
		Main:SubMenu({ Name = "Pitch", Build = function(menu)
			menu:Section({ Name = "Pitch Settings", Border = true }, function(section)
				section:Toggle({ Name = "Checkbox" })
			end)
		end })
		Window:Finish()                                               -- always last

	Box heights: Height = "auto" (default), a number of pixels, 0 to fill the column, or -0.5 for
	half of what is left. A tab grows sub-tabs with Window:Tab({...}):EnableChildren() and then
	Window:Tab({ Parent = thatTab, ... }). A toggle takes Color = Library.Color(Color3) for a swatch
	or Options = function(card) ... end for a "..." button. Icon names are the keys of GlyphData.
	Slider value boxes can be typed into. Every control returns an object with :Set(value), :Get().

	Saving. With an executor's file functions (writefile, readfile, isfile, isfolder, makefolder,
	listfiles, delfile) everything lives under the Folder option, by default "NeverloseReloaded":

		configs/<name>.json   one file per preset, holding every control's value
		trash/<name>.json     deleted presets, until they are purged from the bin
		themes/<name>.json    colour palettes
		settings.json         theme, accent colour, language, scale, last preset

	Without those functions (plain Studio) the same features work for the session, in memory.

	Controls are matched to saved values by path, such as "Rage/MAIN/Enabled". Give a control
	Flag = "MyName" to fix its id, or Flag = false to leave it out of configs. Combo/Multi support
	Searchable = true; Flow also provides NumberInput, Stepper, Segmented, Radio, Color:Set/Get,
	Text, Status, Progress, collapsible Section, and virtualized DataTable controls. Window actions
	registered with :RegisterAction appear in the Ctrl+K command palette. Library:SetReducedMotion(true)
	disables transitions and is saved with the menu settings.

	Window:SetTitle, Window:SetSubtitle, Window:SetDescription, and Window:SetAccount update the
	window branding and local profile panel. Account accepts Name, Status, ActionText, and OnAction;
	OnAction receives the window and current profile. This is profile display only, not authentication.
	Never put passwords, API keys, or authorization secrets in a client-loaded script.

	Themes. Dark.json and Light.json are written on first run. Edit them, or drop in another file,
	and it appears under Style. { "Colors": { "Body": "0B0E16", "Text": "EBEBF0" } } is a whole
	theme: anything left out comes from Dark. A colour is RRGGBB or RRGGBBAA. The names are the keys
	of Palettes below.

	Controls without a game to drive are visual only: the Shader tab's effects need real shaders,
	and the Spotify widget shows its offline state because Roblox has no media session to read.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local AssetService = (pcall(function() return game:GetService("AssetService") end) and game:GetService("AssetService")) or nil
local StatsService = (pcall(function() return game:GetService("Stats") end) and game:GetService("Stats")) or nil

local HasEditableImage = false
if AssetService then
	pcall(function()
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(1, 1) })
		if img then
			HasEditableImage = true
			pcall(function() img:Destroy() end)
		end
	end)
end
local CanEditableImage = HasEditableImage and (type(buffer) == "table" and type(buffer.create) == "function" and type(buffer.writeu8) == "function")

local Library = { Language = 0, Theme = "Dark", ThemeNames = { "Dark", "Light" }, ReducedMotion = false }
local ReducedMotion = false

local floor, ceil, max, min, abs, exp, huge = math.floor, math.ceil, math.max, math.min, math.abs, math.exp, math.huge
local function round(x) return floor(x + 0.5) end
local function clamp(x, a, b) return (x < a and a) or (x > b and b) or x end
local function sat(x) return clamp(x, 0, 1) end

local FONT_ID = "rbxassetid://12187365364" -- Inter
local FontRegular = Font.new(FONT_ID, Enum.FontWeight.Regular)
local FontMedium = Font.new(FONT_ID, Enum.FontWeight.Medium)
local FontSemi = Font.new(FONT_ID, Enum.FontWeight.SemiBold)

--[[ ---------------------------------------- Theme ---------------------------------------- ]]

local function rgb(r, g, b, a) return { Color3.new(r, g, b), a or 1 } end
local function u8(r, g, b, a) return { Color3.fromRGB(r, g, b), a or 1 } end

local Palettes = {
	Dark = {
		Text = rgb(.922, .922, .941), Disabled = rgb(.51, .52, .56), Soft = rgb(.76, .77, .81),
		Border = rgb(.118, .129, .173), PopupBorder = rgb(.165, .18, .235),
		FrameInactive = rgb(.098, .11, .149), FrameActive = rgb(.043, .07, .137), TabActive = rgb(.153, .169, .212),
		Button = rgb(.102, .102, .133), ButtonHovered = rgb(.05, .054, .078), ButtonActive = rgb(.07, .074, .098),
		Side = rgb(.071, .078, .114), Top = rgb(.043, .059, .09), Body = rgb(.043, .055, .086),
		Group = rgb(.071, .078, .114), Popup = rgb(.071, .078, .114), FieldBg = u8(25, 27, 36),
		SwitchOff = rgb(.055, .071, .098), SwitchRim = rgb(1, 1, 1, .07), KnobOff = rgb(.498, .529, .557),
		Divider = rgb(1, 1, 1, 30 / 255), LabelOff = u8(150, 150, 150), LabelOn = rgb(1, 1, 1),
		Separator = rgb(.11, .122, .157), Ink = rgb(1, 1, 1), SwatchLine = rgb(1, 1, 1, .08),
		Success = rgb(.22, .76, .47), Warning = rgb(.98, .68, .25), Error = rgb(.91, .31, .34), Info = rgb(.35, .54, .98),
	},
	Light = {
		Text = rgb(.11, .118, .145), Disabled = rgb(.463, .482, .529), Soft = rgb(.31, .325, .369),
		Border = rgb(.855, .867, .894), PopupBorder = rgb(.8, .816, .855),
		FrameInactive = rgb(.89, .902, .929), FrameActive = rgb(.82, .859, .957), TabActive = rgb(.851, .871, .918),
		Button = rgb(.906, .914, .937), ButtonHovered = rgb(.867, .878, .906), ButtonActive = rgb(.831, .843, .875),
		Side = rgb(.918, .925, .945), Top = rgb(.957, .961, .973), Body = rgb(.945, .949, .965),
		Group = rgb(.988, .988, .992), Popup = rgb(.965, .969, .98), FieldBg = rgb(.898, .906, .933),
		SwitchOff = rgb(.792, .808, .847), SwitchRim = rgb(0, 0, 0, .06), KnobOff = rgb(1, 1, 1),
		Divider = rgb(0, 0, 0, .1), LabelOff = rgb(.463, .482, .529), LabelOn = rgb(.11, .118, .145),
		Separator = rgb(.855, .867, .894), Ink = rgb(.11, .118, .145), SwatchLine = rgb(0, 0, 0, .12),
		Success = rgb(.12, .53, .31), Warning = rgb(.7, .42, .08), Error = rgb(.75, .2, .22), Info = rgb(.2, .38, .82),
	},
}

local Accent = Color3.new(.318, .486, .992)
local White, Black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local T, A = {}, {}

local Fallback = Palettes.Dark -- a theme file may name only some colours; the rest come from here

local function applyPalette()
	local palette = Palettes[Library.Theme] or Fallback
	for name, value in Fallback do
		local entry = palette[name] or value
		T[name], A[name] = entry[1], entry[2]
	end
	T.Title = T.Ink
end
applyPalette()

--[[ ---------------------------------------- Translations --------------------------------- ]]

local Translations = {
	["Search functions..."] = { "Поиск функций...", "İşlev ara..." },
	["No matching functions"] = { "Ничего не найдено", "Eşleşen işlev yok" },
	["No matching options"] = { "Варианты не найдены", "Eşleşen seçenek yok" },
	["Functions"] = { "Функции", "İşlevler" },
	["ENEMY"] = { "ВРАГ", "DÜŞMAN" },
	["ENEMY MODEL"] = { "МОДЕЛЬ ВРАГА", "DÜŞMAN MODELİ" },
	["Offscreen Arrow"] = { "Стрелка за экраном", "Ekran Dışı Ok" },
	["Sounds"] = { "Звуки", "Sesler" },
	["Player"] = { "Игрок", "Oyuncu" },
	["Behind Walls"] = { "Сквозь стены", "Duvar Arkası" },
	["On Shot"] = { "При выстреле", "Ateş Anında" },
	["History"] = { "История", "Geçmiş" },
	["Ragdolls"] = { "Рэгдоллы", "Ragdoll" },
	["Flat"] = { "Плоский", "Düz" },
	["Chams"] = { "Chams", "Chams" },
	["Enemies"] = { "Враги", "Düşmanlar" },
	["Friends"] = { "Союзники", "Dostlar" },
	["ESP Items"] = { "Элементы ESP", "ESP Öğeleri" },
	["Main"] = { "Основное", "Ana" },
	["Flags"] = { "Флаги", "Bayraklar" },
	["Weapon"] = { "Оружие", "Silah" },
	["Aimbot"] = { "Аимбот", "Aimbot" },
	["Bounding Box"] = { "Рамка", "Çerçeve" },
	["Distance"] = { "Дистанция", "Mesafe" },
	["Health Bar"] = { "Полоса здоровья", "Can Barı" },
	["Ammo Bar"] = { "Полоса патронов", "Mermi Barı" },
	["Skeleton"] = { "Скелет", "İskelet" },
	["Unarmored"] = { "Без брони", "Zırhsız" },
	["Defuser"] = { "Дефузер", "Defuser" },
	["Blind"] = { "Ослеплён", "Kör" },
	["Scoped"] = { "В прицеле", "Dürbünde" },
	["Reload"] = { "Перезарядка", "Şarjör" },
	["Immunity"] = { "Иммунитет", "Dokunulmazlık" },
	["Slowed"] = { "Замедлен", "Yavaşlamış" },
	["Vulnerable"] = { "Уязвим", "Savunmasız" },
	["Hostage"] = { "Заложник", "Rehine" },
	["Defuse"] = { "Разминирование", "Bomba İmha" },
	["Pin Pulled"] = { "Чека выдернута", "Pimi Çekili" },
	["Money"] = { "Деньги", "Para" },
	["Order Priority"] = { "Приоритет", "Öncelik" },
	["Delay"] = { "Задержка", "Gecikme" },
	["Icon"] = { "Иконка", "İkon" },
	["Readiness Bar"] = { "Готовность", "Hazırlık Barı" },
	["Taser"] = { "Тазер", "Tazer" },
	["Hit Chance"] = { "Шанс попадания", "İsabet Şansı" },
	["Hitboxes"] = { "Хитбоксы", "Hitbox" },
	["VIEW"] = { "ОБЗОР", "GÖRÜŞ" },
	["HUD"] = { "ИНТЕРФЕЙС", "HUD" },
	["WORLD ESP"] = { "ESP МИРА", "DÜNYA ESP" },
	["MISCELLANEOUS"] = { "ПРОЧЕЕ", "ÇEŞİTLİ" },
	["View Options"] = { "Настройки обзора", "Görüş Ayarları" },
	["Scope Options"] = { "Настройки прицела", "Dürbün Ayarları" },
	["Viewmodel Options"] = { "Настройки вьюмодели", "Viewmodel Ayarları" },
	["Perspective Options"] = { "Настройки перспективы", "Perspektif Ayarları" },
	["Unlock Spectating"] = { "Свободный обзор", "Serbest İzleme" },
	["Visual Recoil"] = { "Визуальная отдача", "Görsel Geri Tepme" },
	["Radar"] = { "Радар", "Radar" },
	["Scope Overlay"] = { "Оверлей прицела", "Dürbün Kaplaması" },
	["Inaccuracy Overlay"] = { "Оверлей разброса", "Sapma Göstergesi" },
	["Death Notices"] = { "Сообщения о смертях", "Ölüm Bildirimleri" },
	["Scoreboard"] = { "Таблица счёта", "Skor Tablosu" },
	["Crosshairs"] = { "Прицелы", "Nişangahlar" },
	["Bomb"] = { "Бомба", "Bomba" },
	["Weapons"] = { "Оружие", "Silahlar" },
	["Hostages"] = { "Заложники", "Rehineler" },
	["Grenades"] = { "Гранаты", "El Bombaları" },
	["Grenade Trajectory"] = { "Траектория гранат", "Bomba Yörüngesi" },
	["Grenade Proximity Warnings"] = { "Предупреждения о гранатах", "Bomba Yakınlık Uyarısı" },
	["Windows"] = { "Окна", "Pencereler" },
	["Removals"] = { "Удаления", "Kaldırmalar" },
	["Ambience"] = { "Атмосфера", "Atmosfer" },
	["Hit Marker"] = { "Хитмаркер", "İsabet İşareti" },
	["Bullet Tracers"] = { "Трассеры", "Mermi İzleri" },
	["Bullet Impacts"] = { "Попадания", "Mermi Çarpmaları" },
	["MAP SELECTION"] = { "ВЫБОР КАРТЫ", "HARİTA SEÇİMİ" },
	["EFFECTS"] = { "ЭФФЕКТЫ", "EFEKTLER" },
	["Global"] = { "Глобально", "Genel" },
	["Main Menu"] = { "Главное меню", "Ana Menü" },
	["Add"] = { "Добавить", "Ekle" },
	["Nightmode"] = { "Ночной режим", "Gece Modu" },
	["Fullbright"] = { "Полная яркость", "Tam Aydınlık" },
	["Exposure"] = { "Экспозиция", "Pozlama" },
	["Sunlight"] = { "Солнечный свет", "Güneş Işığı" },
	["Sky"] = { "Небо", "Gökyüzü" },
	["Fog"] = { "Туман", "Sis" },
	["Bloom"] = { "Свечение", "Parlama" },
	["Vignette"] = { "Виньетка", "Vinyet" },
	["Local Contrast"] = { "Локальный контраст", "Yerel Kontrast" },
	["Color Correction"] = { "Цветокоррекция", "Renk Düzeltme" },
	["Depth of Field"] = { "Глубина резкости", "Alan Derinliği" },
	["Smoke"] = { "Дым", "Duman" },
	["Flashbang"] = { "Флешка", "Flash" },
	["Scope Blur"] = { "Размытие прицела", "Dürbün Bulanıklığı" },
	["Added the current map"] = { "Карта добавлена", "Geçerli harita eklendi" },
	["Show On Death"] = { "Показывать после смерти", "Ölümde Göster" },
	["Blur On Shader"] = { "Размытие шейдера", "Shader Bulanıklığı" },
	["Blur Intensity"] = { "Сила размытия", "Bulanıklık Yoğunluğu" },
	["Blur the selected effect behind the menu."] = { "Размывает выбранный эффект за меню.", "Menünün arkasındaki seçili efekti bulanıklaştırır." },
	["Opacity"] = { "Прозрачность", "Saydamlık" },
	["Mode"] = { "Режим", "Mod" },
	["Amount"] = { "Сила", "Miktar" },
	["Line"] = { "Линия", "Çizgi" },
	["Dots"] = { "Точки", "Noktalar" },
	["Arrows"] = { "Стрелки", "Oklar" },
	["Affect Foliage"] = { "Влиять на листву", "Bitkileri Etkile" },
	["Players Only"] = { "Только игроки", "Sadece Oyuncular" },
	["Size"] = { "Размер", "Boyut" },
	["Outline"] = { "Обводка", "Dış Çizgi" },
	["Filled"] = { "Заливка", "Dolu" },
	["Outlined"] = { "Обведённый", "Çizgili" },
	["Soft"] = { "Мягкий", "Yumuşak" },
	["Strong"] = { "Сильный", "Güçlü" },
	["Always"] = { "Всегда", "Her Zaman" },
	["In Air"] = { "В воздухе", "Havadayken" },
	["On Key"] = { "По клавише", "Tuşla" },
	["Classic"] = { "Классический", "Klasik" },
	["Minimal"] = { "Минимальный", "Sade" },
	["AIMBOT"] = { "ПРИЦЕЛ", "NİŞAN" },
	["COMMON"] = { "ОБЩЕЕ", "GENEL" },
	["Rage"] = { "Рейдж", "Rage" },
	["Legit"] = { "Легит", "Legit" },
	["Visuals"] = { "Визуалы", "Görseller" },
	["Players"] = { "Игроки", "Oyuncular" },
	["World"] = { "Мир", "Dünya" },
	["Miscellaneous"] = { "Разное", "Çeşitli" },
	["Components"] = { "Компоненты", "Bileşenler" },
	["Curve Lab"] = { "Кривая", "Eğri Atölyesi" },
	["Typography"] = { "Типографика", "Tipografi" },
	["MAIN"] = { "ОСНОВНОЕ", "ANA" },
	["SELECTION"] = { "ВЫБОР", "SEÇİM" },
	["OTHER"] = { "ДРУГОЕ", "DİĞER" },
	["ANTI-AIM"] = { "АНТИ-АИМ", "ANTI-AIM" },
	["Enabled"] = { "Включено", "Etkin" },
	["Silent Aim"] = { "Тихий аим", "Sessiz Nişan" },
	["Automatic Fire"] = { "Автострельба", "Otomatik Ateş" },
	["Aim Through Walls"] = { "Сквозь стены", "Duvar Arkasına Nişan" },
	["Field Of View"] = { "Поле зрения", "Görüş Alanı" },
	["Pitch"] = { "Питч", "Pitch" },
	["Yaw"] = { "Яв", "Yaw" },
	["Freestanding"] = { "Фристендинг", "Freestanding" },
	["Mouse Override"] = { "Управление мышью", "Fare Kontrolü" },
	["Checkbox"] = { "Флажок", "Onay Kutusu" },
	["Combo"] = { "Список", "Liste" },
	["Multi"] = { "Мульти", "Çoklu" },
	["Slider"] = { "Ползунок", "Kaydırıcı" },
	["Kill Effect"] = { "Эффект убийства", "Öldürme Efekti" },
	["Additional Colors"] = { "Доп. цвета", "Ek Renkler" },
	["Glow"] = { "Свечение", "Parlama" },
	["Name"] = { "Имя", "İsim" },
	["Weather"] = { "Погода", "Hava Durumu" },
	["Wind"] = { "Ветер", "Rüzgar" },
	["Model Wetness"] = { "Мокрые модели", "Model Islaklığı" },
	["Thunder"] = { "Гром", "Gök Gürültüsü" },
	["Rain"] = { "Дождь", "Yağmur" },
	["Snow"] = { "Снег", "Kar" },
	["Layout"] = { "Макет", "Düzen" },
	["Background"] = { "Фон", "Arka Plan" },
	["Border"] = { "Рамка", "Kenarlık" },
	["Accent"] = { "Акцент", "Vurgu" },
	["Text"] = { "Текст", "Metin" },
	["Spread Force"] = { "Сила разброса", "Yayılma Gücü" },
	["Speed"] = { "Скорость", "Hız" },
	["Font"] = { "Шрифт", "Yazı Tipi" },
	["Case"] = { "Регистр", "Harf Düzeni" },
	["Draw Avatar"] = { "Показывать аватар", "Avatarı Göster" },
	["Regular"] = { "Обычный", "Normal" },
	["Bold"] = { "Жирный", "Kalın" },
	["Italic"] = { "Курсив", "İtalik" },
	["Default"] = { "По умолчанию", "Varsayılan" },
	["Uppercase"] = { "Прописные", "Büyük Harf" },
	["Lowercase"] = { "Строчные", "Küçük Harf" },
	["Select"] = { "Выбрать", "Seç" },
	["Head"] = { "Голова", "Kafa" },
	["Chest"] = { "Грудь", "Göğüs" },
	["Stomach"] = { "Живот", "Karın" },
	["Legs"] = { "Ноги", "Bacaklar" },
	["Click to enable or disable this option."] = { "Нажмите, чтобы включить или выключить.", "Açmak veya kapatmak için tıklayın." },
	["Open this section to adjust its settings."] = { "Откройте раздел, чтобы настроить его.", "Ayarlarını değiştirmek için bu bölümü açın." },
	["Adjust the field of view in degrees."] = { "Настройка поля зрения в градусах.", "Görüş alanını derece cinsinden ayarlayın." },
	["Select one item from the list."] = { "Выберите один пункт из списка.", "Listeden bir öğe seçin." },
	["Select one or more items. Click a selected item again to remove it."] = { "Выберите один или несколько пунктов. Нажмите на выбранный ещё раз, чтобы убрать его.", "Bir veya daha fazla öğe seçin. Kaldırmak için seçili öğeye tekrar tıklayın." },
	["Drag the bar to adjust the value from 0 to 100."] = { "Перетащите ползунок, чтобы задать значение от 0 до 100.", "Değeri 0 ile 100 arasında ayarlamak için çubuğu sürükleyin." },
	["Click the swatch to edit the color."] = { "Нажмите на образец, чтобы изменить цвет.", "Rengi düzenlemek için renk kutusuna tıklayın." },
	["Click the swatch to edit the colors."] = { "Нажмите на образец, чтобы изменить цвета.", "Renkleri düzenlemek için renk kutusuna tıklayın." },
	["Language"] = { "Язык", "Dil" },
	["Menu Scale"] = { "Масштаб меню", "Menü Ölçeği" },
	["ESP Scale"] = { "Масштаб ESP", "ESP Ölçeği" },
	["Windows Scale"] = { "Масштаб окон", "Pencere Ölçeği" },
	["Units"] = { "Единицы", "Birimler" },
	["Style"] = { "Стиль", "Stil" },
	["Safe Mode"] = { "Безопасный режим", "Güvenli Mod" },
	["Synchronization"] = { "Синхронизация", "Senkronizasyon" },
	["About"] = { "О программе", "Hakkında" },
	["Chat"] = { "Чат", "Sohbet" },
	["Renew"] = { "Продлить", "Yenile" },
	["Lifetime"] = { "Навсегда", "Ömür Boyu" },
	["Till: Lifetime"] = { "До: навсегда", "Bitiş: Ömür Boyu" },
	["English"] = { "English", "English" },
	["Russian"] = { "Русский", "Русский" },
	["Turkish"] = { "Türkçe", "Türkçe" },
	["Dark"] = { "Тёмная", "Koyu" },
	["Light"] = { "Светлая", "Açık" },
	["Auto"] = { "Авто", "Otomatik" },
	["Metric"] = { "Метрические", "Metrik" },
	["Imperial"] = { "Имперские", "Emperyal" },
	["Disabled"] = { "Выключено", "Kapalı" },
	["Presets"] = { "Пресеты", "Ön Ayarlar" },
	["Search"] = { "Поиск", "Ara" },
	["Newest First"] = { "Сначала новые", "Önce En Yeni" },
	["Recently Modified"] = { "Недавно изменённые", "Son Değiştirilen" },
	["Alphabetical"] = { "По алфавиту", "Alfabetik" },
	["Share"] = { "Поделиться", "Paylaş" },
	["Duplicate"] = { "Дублировать", "Çoğalt" },
	["Delete"] = { "Удалить", "Sil" },
	["Bin is empty"] = { "Корзина пуста", "Çöp kutusu boş" },
	["No presets found"] = { "Пресеты не найдены", "Ön ayar bulunamadı" },
	["Cloud"] = { "Облако", "Bulut" },
	["Config Created"] = { "Конфиг создан", "Yapılandırma Oluşturuldu" },
	["Config Saved"] = { "Конфиг сохранён", "Yapılandırma Kaydedildi" },
	["Config Loaded"] = { "Конфиг загружен", "Yapılandırma Yüklendi" },
	["Config Deleted"] = { "Конфиг удалён", "Yapılandırma Silindi" },
	["Config Renamed"] = { "Конфиг переименован", "Yapılandırma Yeniden Adlandırıldı" },
	["Config Restored"] = { "Конфиг восстановлен", "Yapılandırma Geri Yüklendi" },
	["Config Duplicated"] = { "Конфиг продублирован", "Yapılandırma Çoğaltıldı" },
	["Created new config"] = { "Создан новый конфиг", "Yeni yapılandırma oluşturuldu" },
	["Saved changes to %s"] = { "Изменения сохранены: %s", "%s kaydedildi" },
	["Loaded config: %s"] = { "Загружен конфиг: %s", "Yüklendi: %s" },
	["Removed config: %s"] = { "Удалён конфиг: %s", "Silindi: %s" },
	["Uploaded %s to the cloud"] = { "%s загружен в облако", "%s buluta yüklendi" },
	["Downloaded %s"] = { "Скачан %s", "%s indirildi" },
	["Copied a share link for %s"] = { "Ссылка на %s скопирована", "%s için paylaşım bağlantısı kopyalandı" },
	["Duplicated %s"] = { "Продублирован %s", "%s çoğaltıldı" },
	["Restored %s"] = { "Восстановлен %s", "%s geri yüklendi" },
	["Renamed %s to %s"] = { "%s переименован в %s", "%s, %s olarak yeniden adlandırıldı" },
	["Copied %s to the clipboard"] = { "%s скопирован в буфер обмена", "%s panoya kopyalandı" },
	["Clipboard is not available"] = { "Буфер обмена недоступен", "Pano kullanılamıyor" },
}


local function tr(text)
	local row = Library.Language > 0 and Translations[text]
	return row and row[Library.Language] or text
end

--[[ ---------------------------------------- Instances ------------------------------------ ]]

local function New(class, props, parent)
	local object = Instance.new(class)
	for key, value in props do object[key] = value end
	if parent then object.Parent = parent end
	return object
end

local function Box(parent, x, y, w, h, color, radius)
	local frame = New("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0,
		BackgroundColor3 = color or White, BackgroundTransparency = color and 0 or 1,
	}, parent)
	if radius then New("UICorner", { CornerRadius = UDim.new(0, radius) }, frame) end
	return frame
end

local function Stroke(frame, color, thickness)
	return New("UIStroke", {
		Color = color or White, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

-- Not every client has UIShadow yet. Those that don't simply go without a shadow.
local function Shadow(parent, blur, transparency, offsetY)
	local ok, shadow = pcall(function()
		return New("UIShadow", {
			BlurRadius = UDim.new(0, blur), Color = Black, Offset = UDim2.fromOffset(0, offsetY or 0), Transparency = transparency,
		}, parent)
	end)
	return ok and shadow or nil
end

local function setXY(frame, x, y) frame.Position = UDim2.fromOffset(x, y) end
local function setWH(frame, w, h) frame.Size = UDim2.fromOffset(w, h) end

--[[ ---------------------------------------- Files ----------------------------------------- ]]

local hasDisk = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function"

local Files = { memory = {}, disk = hasDisk }

function Files.folder(path)
	if hasDisk then pcall(function() if not isfolder(path) then makefolder(path) end end) end
end

function Files.write(path, text)
	if not text then return end
	if hasDisk then pcall(writefile, path, text) else Files.memory[path] = text end
end

function Files.read(path)
	if not hasDisk then return Files.memory[path] end
	local ok, text = pcall(function() return isfile(path) and readfile(path) or nil end)
	return ok and text or nil
end

function Files.delete(path)
	if not hasDisk then
		Files.memory[path] = nil
	elseif type(delfile) == "function" then
		pcall(delfile, path)
	end
end

function Files.list(folder)
	local names = {}
	if hasDisk then
		local ok, paths = pcall(listfiles, folder)
		if ok then
			for _, path in paths do table.insert(names, string.match(path, "([^/\\]+)$")) end
		end
	else
		local prefix = folder .. "/"
		for path in Files.memory do
			if string.sub(path, 1, #prefix) == prefix then table.insert(names, string.sub(path, #prefix + 1)) end
		end
	end
	table.sort(names)
	return names
end

local function encodeJSON(value)
	local ok, text = pcall(HttpService.JSONEncode, HttpService, value)
	return ok and text or nil
end

local function decodeJSON(text)
	if not text then return nil end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, text)
	return ok and value or nil
end

local function toHex(color, alpha)
	local text = string.format("%02X%02X%02X", round(color.R * 255), round(color.G * 255), round(color.B * 255))
	if alpha and alpha < 1 then text ..= string.format("%02X", round(alpha * 255)) end
	return text
end

local function fromHex(text)
	if type(text) ~= "string" then return nil end
	local digits = string.gsub(text, "[^%x]", "")
	if #digits ~= 6 and #digits ~= 8 then return nil end
	local function byte(i) return tonumber(string.sub(digits, i, i + 1), 16) end
	return Color3.fromRGB(byte(1), byte(3), byte(5)), #digits == 8 and byte(7) / 255 or 1
end

local function safeName(name) return (string.gsub(name, '[\\/:*?"<>|]', "_")) end

--[[ ---------------------------------------- Screen ---------------------------------------- ]]

local Screen, Stage, StageScale, Probe
local Scale = 1
local function buildScreen()
	if Screen then return end
	local parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local previous = parent:FindFirstChild("NeverloseReloaded")
	if previous then previous:Destroy() end
	Screen = New("ScreenGui", {
		Name = "NeverloseReloaded", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, parent)
	Stage = Box(Screen, 0, 0, 0, 0)
	Stage.Size = UDim2.fromScale(1, 1)
	StageScale = New("UIScale", { Scale = 1 }, Stage)
	Probe = New("TextLabel", {
		Text = "", BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.fromOffset(1000, 40),
		Position = UDim2.fromOffset(-2000, -2000), FontFace = FontMedium, TextSize = 12,
	}, Screen)
end

local Widths, WidthKeys = {}, {}
local WidthLimit, WidthCount, WidthCursor = 2048, 0, 1
local function measure(text, size, font)
	local key = (font == FontSemi and "S" or "M") .. size .. text
	local cached = Widths[key]
	if cached then return cached end
	Probe.FontFace, Probe.TextSize, Probe.Text = font or FontMedium, size, text
	local width = Probe.TextBounds.X
	if width > 0 then
		if WidthCount < WidthLimit then
			WidthCount += 1
			WidthKeys[WidthCount] = key
		else
			local expired = WidthKeys[WidthCursor]
			Widths[expired] = nil
			WidthKeys[WidthCursor] = key
			WidthCursor = WidthCursor % WidthLimit + 1
		end
		Widths[key] = width
	end
	return width
end

-- Inter is a cloud font, so everything measured must wait until it has arrived.
local function preloadFonts()
	local ok, service = pcall(game.GetService, game, "TextService")
	if not ok or not service then return end
	for _, font in { FontMedium, FontSemi } do
		pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text, params.Font, params.Size, params.Width = "Neverlose", font, 12, 500
			service:GetTextBoundsAsync(params)
		end)
	end
end

-- Mouse in the same space as AbsolutePosition.
local function mouseAbs() return UserInputService:GetMouseLocation() + Screen.AbsolutePosition end
local function toStage(point) return (point - Stage.AbsolutePosition) / Scale end
local function inside(gui, p)
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return p.X >= a.X and p.Y >= a.Y and p.X < a.X + s.X and p.Y < a.Y + s.Y
end
local function viewport() return Stage.AbsoluteSize / Scale end

--[[ ---------------------------------------- Scopes ---------------------------------------- ]]
-- A scope owns painters (redrawn on theme, language and fades) and hit regions. Its effective
-- alpha is what a pushed ImGuiStyleVar_Alpha would have been.

local Scope = {}
Scope.__index = Scope

local function newScope(parent, win)
	local scope = setmetatable({
		parent = parent, win = win or (parent and parent.win), own = 1,
		alpha = parent and parent.alpha or 1, painters = {}, items = {},
		wheels = {}, kids = {}, jobs = {}, connections = {}, cleanups = {}, inert = false, dirty = false, gridDirty = true,
		buckets = {}, originGui = nil, destroyed = false,
	}, Scope)
	if parent then table.insert(parent.kids, scope) end
	return scope
end

function Scope:paint(fn)
	table.insert(self.painters, fn)
	fn()
	return fn
end

function Scope:destroy()
	if self.destroyed then return end
	self.destroyed = true
	if self.parent then
		local index = table.find(self.parent.kids, self)
		if index then table.remove(self.parent.kids, index) end
		self.parent = nil
	end
	while #self.kids > 0 do
		self.kids[#self.kids]:destroy()
	end
	for job in self.jobs do job.cancel() end
	for connection in self.connections do connection:Disconnect() end
	for _, cleanup in self.cleanups do cleanup() end
	table.clear(self.jobs)
	table.clear(self.connections)
	table.clear(self.cleanups)
	table.clear(self.painters)
	table.clear(self.items)
	table.clear(self.wheels)
	if self.buckets then table.clear(self.buckets) end
end

function Scope:onDestroy(cleanup)
	if self.destroyed then
		cleanup()
	else
		table.insert(self.cleanups, cleanup)
	end
end

function Scope:invalidateGrid(recursive)
	self.gridDirty = true
	if recursive then
		for _, kid in self.kids do
			kid:invalidateGrid(true)
		end
	end
end

function Scope:rebuildGrid()
	self.gridDirty = false
	local buckets = {}
	self.buckets = buckets
	local origin = (self.originGui and self.originGui.AbsolutePosition) or Vector2.zero
	for _, item in self.items do
		local gui = item.gui
		if gui and gui.Parent then
			local a, s = gui.AbsolutePosition, gui.AbsoluteSize
			local lx, ly = a.X - origin.X, a.Y - origin.Y
			local bx0 = floor(lx / 64)
			local by0 = floor(ly / 64)
			local bx1 = floor((lx + s.X) / 64)
			local by1 = floor((ly + s.Y) / 64)
			for bx = bx0, bx1 do
				for by = by0, by1 do
					local key = bx * 10000 + by
					local bucket = buckets[key]
					if not bucket then
						bucket = {}
						buckets[key] = bucket
					end
					table.insert(bucket, item)
				end
			end
		end
	end
end

function Scope:refresh()
	if self.destroyed then return end
	if self.win and self.win.frame and not self.win.frame.Visible then
		self.dirty = true
		return
	end
	self.dirty = false
	self.alpha = self.own * (self.parent and self.parent.alpha or 1)
	for _, fn in self.painters do fn() end
	for _, kid in self.kids do kid:refresh() end
end

function Scope:setAlpha(alpha)
	if self.own ~= alpha then
		self.own = alpha
		self:refresh()
	end
end

local Root = newScope(nil)

--[[ ---------------------------------------- Animation & Demand-Driven Loop ----------------- ]]

local Moving, Queue, Stepping = {}, {}, false
local Tickers = {}
local RenderConnection = nil
local wakeLoop, sleepLoop
local updatePointer

local function Anim(value, speed, callback, epsilon)
	return setmetatable({ v = value, t = value, speed = speed or 15, cb = callback, eps = epsilon or 0.002 }, { __index = {
		to = function(self, target, newSpeed)
			if newSpeed then self.speed = newSpeed end
			if ReducedMotion then
				self:set(target)
				return
			end
			self.t = target
			if self.v ~= target then
				if Stepping then Queue[self] = true else Moving[self] = true end
				wakeLoop()
			end
		end,
		set = function(self, value2)
			self.v, self.t = value2, value2
			Moving[self], Queue[self] = nil, nil
			if self.cb then self.cb(value2) end
		end,
	} })
end

local function Run(fn, owner)
	if owner and owner.destroyed then
		return function() end
	end
	local job = { callback = fn, owner = owner }
	Tickers[job] = true
	function job.cancel()
		if not Tickers[job] then return end
		Tickers[job] = nil
		if owner then owner.jobs[job] = nil end
	end
	if owner then owner.jobs[job] = true end
	wakeLoop()
	return job.cancel
end

local function stepAnimations(dt)
	dt = min(dt, 0.05)
	Stepping = true
	for anim in Moving do
		anim.v += (anim.t - anim.v) * (1 - exp(-anim.speed * dt))
		if abs(anim.t - anim.v) < anim.eps then
			anim.v = anim.t
			Moving[anim] = nil
		end
		if anim.cb then anim.cb(anim.v) end
	end
	for job in Tickers do
		if job.owner and job.owner.destroyed then
			job.cancel()
		elseif job.callback(dt) == false then
			job.cancel()
		end
	end
	Stepping = false
	for anim in Queue do Moving[anim] = true end
	table.clear(Queue)
end

--[[ ---------------------------------------- Input ----------------------------------------- ]]
-- ImGui's rules, not Roblox's: the top popup owns the pointer, a press outside only closes,
-- the held widget keeps the pointer, and the first widget submitted wins an overlap.

local Popups, Windows = {}, {}
local Hover, Held, Dragging = nil, nil, nil
local Tip = { item = nil, time = 0 }
local ShowTip, HideTip
local refreshKeybindHUD

sleepLoop = function()
	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end
end

wakeLoop = function()
	if RenderConnection then return end
	RenderConnection = RunService.RenderStepped:Connect(function(dt)
		stepAnimations(dt)
		updatePointer(dt)
		if next(Moving) == nil and next(Tickers) == nil and not Dragging and not Held and (Tip.item == nil or Tip.time > 0.6) then
			sleepLoop()
		end
	end)
end

local function Hit(scope, gui, handlers)
	handlers.gui = gui
	table.insert(scope.items, handlers)
	scope:invalidateGrid()
	return handlers
end

local function Wheel(scope, gui, fn)
	table.insert(scope.wheels, { gui = gui, fn = fn })
end

local function pick(scope, p, field)
	if scope.inert or (scope.clip and not inside(scope.clip, p)) then return nil end
	for i = #scope.kids, 1, -1 do
		local found = pick(scope.kids[i], p, field)
		if found then return found end
	end
	if field == "items" and scope.buckets then
		if scope.gridDirty then scope:rebuildGrid() end
		local origin = (scope.originGui and scope.originGui.AbsolutePosition) or Vector2.zero
		local bx = floor((p.X - origin.X) / 64)
		local by = floor((p.Y - origin.Y) / 64)
		local bucket = scope.buckets[bx * 10000 + by]
		if bucket then
			for _, item in bucket do
				if item.gui.Visible ~= false and not item.off and inside(item.gui, p) then
					return item
				end
			end
		end
		return nil
	end
	for _, item in scope[field] do
		if item.gui.Visible ~= false and not item.off and inside(item.gui, p) then return item end
	end
	return nil
end

local function targetAt(p, field)
	if #Popups > 0 then
		local top = Popups[#Popups]
		return inside(top.frame, p) and pick(top.scope, p, field) or nil
	end
	for i = #Windows, 1, -1 do
		local window = Windows[i]
		if window.frame.Visible and inside(window.frame, p) then return pick(window.scope, p, field) end
	end
	return nil
end

local function setHover(item)
	if Hover == item then return end
	if Hover and Hover.hover then Hover.hover(false) end
	Hover = item
	if item and item.hover then item.hover(true) end
	Tip.item, Tip.time = item, 0
end

updatePointer = function(dt)
	local p = mouseAbs()
	if Held then
		if Held.drag then Held.drag(p) end
	elseif not Dragging then
		setHover(targetAt(p, "items"))
	end
	if Dragging then Dragging(p) end
	local wants = Tip.item and Tip.item.tip and not Held and not Dragging
	if wants then
		Tip.time += dt
		if Tip.time > 0.5 then ShowTip(Tip.item) end
	else
		HideTip()
	end
end

local closePopupsTo

local function beginDrag(owner, p)
	local grab = toStage(p) - owner.dragTarget
	Dragging = function(point) owner:dragTo(toStage(point) - grab) end
end

local function onPress(p)
	if #Popups > 0 then
		local level = 0
		for i = #Popups, 1, -1 do
			if inside(Popups[i].frame, p) then level = i break end
		end
		if level < #Popups then
			closePopupsTo(level)
			return
		end
	end
	setHover(targetAt(p, "items"))
	if Hover then
		Held = Hover
		if Held.down then Held.down(p) end
		return
	end
	if #Popups > 0 then
		beginDrag(Popups[#Popups], p)
		return
	end
	for i = #Windows, 1, -1 do
		local window = Windows[i]
		if window.frame.Visible and inside(window.frame, p) then
			if window.dragTo then beginDrag(window, p) end
			return
		end
	end
end

local function onRelease(p)
	Dragging = nil
	local item = Held
	Held = nil
	if item then
		if item.up then item.up(p) end
		if item.click and inside(item.gui, p) then item.click(p) end
	end
end

local Connected = false
local Connections = {}

local function connect(signal, fn, owner)
	local connection = signal:Connect(fn)
	if owner then
		if owner.destroyed then
			connection:Disconnect()
		else
			owner.connections[connection] = true
		end
	else
		table.insert(Connections, connection)
	end
	return connection
end

local function connectInput()
	if Connected then return end
	Connected = true
	connect(UserInputService.InputBegan, function(input)
		wakeLoop()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPress(mouseAbs())
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			local p = mouseAbs()
			local item = targetAt(p, "items")
			if item and item.right then item.right(p) end
		end
		if refreshKeybindHUD then
			Run(function()
				refreshKeybindHUD()
				return false
			end, Root)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		wakeLoop()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then onRelease(mouseAbs()) end
		if refreshKeybindHUD then
			Run(function()
				refreshKeybindHUD()
				return false
			end, Root)
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		wakeLoop()
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local target = targetAt(mouseAbs(), "wheels")
			if target then target.fn(input.Position.Z) end
		end
	end)
	wakeLoop()
end

--[[ ---------------------------------------- Icons ----------------------------------------- ]]
-- Outlines from the original's icon font, 512 units to the em with y running down from the top
-- of the em. They are rasterised with exact coverage to whatever size the widget asks for, then
-- drawn as runs of 1px frames, which is what a baked font atlas amounts to.

local GlyphData = {
	CROSSHAIRS = {512,"500,224,509,227,512,236,512,276,509,285,500,288,470,288,449,353,408,408,353,449,288,470,288,500,285,509,276,512,236,512,227,509,224,500,224,470,159,449,104,408,63,353,42,288,12,288,3,285,0,276,0,236,3,227,12,224,42,224,63,159,104,104,159,63,224,42,224,12,227,3,236,0,276,0,285,3,288,12,288,42,353,63,408,104,449,159,470,224;288,405,329,390,364,364,390,329,405,288,364,288,355,285,352,276,352,236,355,227,364,224,405,224,390,183,364,148,329,122,288,107,288,148,285,157,276,160,236,160,227,157,224,148,224,107,183,122,148,148,122,183,107,224,148,224,157,227,160,236,160,276,157,285,148,288,107,288,122,329,148,364,183,390,224,405,224,364,227,355,236,352,276,352,285,355,288,364;278,234,288,256,278,278,256,288,234,278,224,256,234,234,256,224"},
	MOUSE = {384,"0,352,0,224,384,224,384,352,379,394,363,432,337,465,304,491,266,507,224,512,160,512,118,507,80,491,47,465,21,432,5,394;176,0,176,192,0,192,0,160,5,118,21,80,47,47,80,21,118,5,160,0;224,0,266,5,304,21,337,47,363,80,379,118,384,160,384,192,208,192,208,0"},
	IMAGE = {512,"464,448,48,448,30,444,14,434,4,418,0,400,0,112,4,94,14,78,30,68,48,64,464,64,482,68,498,78,508,94,512,112,512,400,508,418,498,434,482,444;152,136,133,124,112,120,91,124,72,136,60,155,56,176,60,197,72,216,91,228,112,232,133,228,152,216,164,197,168,176,164,155;64,384,448,384,448,272,360,184,344,184,208,320,152,264,136,264,64,336"},
	USER = {448,"314,218,273,247,224,256,175,247,134,218,105,177,96,128,105,79,134,38,175,9,224,0,273,9,314,38,343,79,352,128,343,177;314,288,365,298,408,328,438,371,448,422,448,464,444,482,434,498,418,508,400,512,48,512,30,508,14,498,4,482,0,464,0,422,10,371,40,328,83,298,134,288,151,288,187,300,224,304,261,300,297,288"},
	GLOBE = {496,"336,160,160,160,174,98,195,50,220,18,248,8,276,18,301,50,322,98;155,192,341,192,344,256,341,320,155,320,152,256;477,160,369,160,349,78,319,18,369,39,414,72,450,112;177,18,146,78,127,160,19,160,46,112,82,72,127,39;487,192,496,256,487,320,373,320,376,256,373,192;120,256,123,320,9,320,0,256,9,192,123,192;160,352,336,352,322,414,301,462,276,494,248,504,220,494,195,462,174,414;319,494,350,434,369,352,477,352,450,400,414,440,369,473;19,352,127,352,147,434,177,494,127,473,82,440,46,400"},
	MAGIC = {512,"224,96,208,64,176,48,208,32,224,0,240,32,272,48,240,64;80,160,53,107,0,80,53,53,80,0,107,53,160,80,107,107;432,288,459,341,512,368,459,395,432,448,405,395,352,368,405,341;503,94,512,117,503,139,139,503,117,512,94,503,9,418,0,395,9,373,373,9,395,0,418,9;359,203,446,117,395,66,309,153"},
	SLIDERS_H = {512,"496,384,508,388,512,400,512,432,508,444,496,448,160,448,160,464,156,476,144,480,112,480,100,476,96,464,96,448,16,448,4,444,0,432,0,400,4,388,16,384,96,384,96,368,100,356,112,352,144,352,156,356,160,368,160,384;496,224,508,228,512,240,512,272,508,284,496,288,416,288,416,304,412,316,400,320,368,320,356,316,352,304,352,288,16,288,4,284,0,272,0,240,4,228,16,224,352,224,352,208,356,196,368,192,400,192,412,196,416,208,416,224;496,64,508,68,512,80,512,112,508,124,496,128,288,128,288,144,284,156,272,160,240,160,228,156,224,144,224,128,16,128,4,124,0,112,0,80,4,68,16,64,224,64,224,48,228,36,240,32,272,32,284,36,288,48,288,64"},
	SAVE = {448,"434,130,444,146,448,164,448,432,444,450,434,466,418,476,400,480,48,480,30,476,14,466,4,450,0,432,0,80,4,62,14,46,30,36,48,32,316,32,334,36,350,46;178,398,199,411,224,416,249,411,270,398,283,377,288,352,283,327,270,306,249,293,224,288,199,293,178,306,165,327,160,352,165,377;320,111,316,103,313,100,305,96,76,96,67,99,64,108,64,212,67,221,76,224,308,224,317,221,320,212"},
	CHEVRON_DOWN = {448,"207,381,13,187,6,170,13,153,35,131,52,124,69,130,224,285,379,130,396,124,413,131,435,153,442,170,435,187,241,381,224,389"},
	CHEVRON_RIGHT = {320,"285,273,91,467,74,474,57,467,35,445,28,428,34,411,189,256,34,101,28,84,35,67,57,45,74,38,91,45,285,239,293,256"},
	SEARCH = {512,"505,443,512,460,505,477,477,505,460,512,443,505,343,405,336,388,336,372,276,405,208,416,153,409,104,389,61,355,27,312,7,263,0,208,7,153,27,104,61,61,104,27,153,7,208,0,263,7,312,27,355,61,389,104,409,153,416,208,405,276,372,336,388,336,405,343;118,298,159,327,208,336,257,327,298,298,327,257,336,208,327,159,298,118,257,89,208,80,159,89,118,118,89,159,80,208,89,257"},
	RUNNING = {416,"306,82,290,92,272,96,254,92,238,82,228,66,224,48,228,30,238,14,254,4,272,0,290,4,306,14,316,30,320,48,316,66;114,317,130,342,152,360,162,366,154,387,136,409,109,416,32,416,10,406,0,384,10,362,32,352,99,352;384,224,406,234,416,256,406,278,384,288,330,288,304,281,287,261,267,220,235,298,297,334,317,358,318,388,287,490,276,506,256,512,246,510,228,495,225,470,253,383,168,333,150,318,140,297,136,274,142,252,179,165,164,160,139,167,99,197,76,204,55,192,48,168,61,146,100,116,139,98,181,99,252,120,288,138,314,171,340,224"},
	AWARD = {384,"98,363,122,379,150,384,185,374,133,502,122,512,107,507,70,469,18,471,4,464,2,449,48,337,73,351,82,353,95,360;384,449,382,464,368,471,316,469,279,507,264,512,253,502,201,374,236,384,264,379,288,363,296,356,301,354,313,351,338,337;264,340,240,352,214,346,193,340,172,346,146,352,122,340,117,335,113,332,109,328,106,326,102,325,96,324,90,322,83,320,65,310,55,291,50,274,46,266,41,258,29,245,18,227,18,206,22,188,24,179,22,170,18,153,18,132,29,113,41,101,46,94,50,85,55,67,65,49,83,38,100,34,108,30,116,25,128,12,146,1,167,1,184,6,193,7,202,6,219,1,240,1,258,12,270,25,278,30,286,34,303,38,321,49,331,67,336,85,340,94,345,101,357,113,368,132,368,153,364,170,362,179,364,188,368,206,368,227,357,245,345,258,340,266,336,274,331,291,321,310,303,320,295,322,288,324,284,326,278,328,274,330,270,334;126,108,106,139,99,176,106,213,126,244,157,265,193,272,229,265,260,244,280,213,287,176,280,139,260,108,229,87,193,80,157,87"},
	WIND = {512,"157,256,192,262,222,280,245,306,255,339,252,380,232,416,200,440,160,448,127,442,98,426,77,401,66,370,69,358,82,352,114,352,124,354,130,362,141,378,160,384,174,381,184,372,192,347,180,328,158,320,16,320,4,316,0,304,0,272,4,260,16,256;16,224,4,220,0,208,0,176,4,164,16,160,350,160,372,152,384,133,376,108,366,99,352,96,333,102,322,118,316,126,306,128,274,128,261,122,258,110,272,75,298,48,334,34,373,34,398,44,420,60,436,82,446,107,446,150,426,188,393,215,352,224;400,256,449,266,488,298,510,343,509,395,498,423,478,448,453,467,424,477,383,479,345,466,314,440,295,405,297,390,310,384,344,384,358,392,376,410,400,416,418,412,434,402,444,386,448,368,444,350,434,334,418,324,400,320,284,320,268,285,244,256"},
	TINT = {352,"205,22,248,122,274,164,297,196,336,260,348,296,352,334,346,381,329,423,300,460,264,489,222,506,176,512,130,506,88,489,52,460,23,423,6,381,0,334,4,296,16,260,56,196,79,163,104,121,147,22,158,6,176,0,195,6;176,448,188,444,192,432,188,420,176,416,145,410,120,392,102,367,96,336,92,324,80,320,68,324,64,336,72,379,97,415,133,440"},
	BOLT = {320,"297,160,309,163,318,172,318,196,142,500,133,509,121,512,102,503,98,482,144,288,25,288,7,280,1,261,33,21,41,6,57,0,201,0,220,10,224,30,182,160"},
	CLOUD_SHOWERS = {512,"416,128,453,135,484,156,505,187,512,224,505,261,484,292,453,313,416,320,96,320,59,313,28,292,7,261,0,224,5,194,18,168,40,147,66,133,64,112,72,69,97,33,133,8,176,0,207,4,234,16,258,36,275,61,302,39,336,32,367,38,392,56,410,81,416,112,414,128;64,384,64,464,60,476,48,480,36,476,32,464,32,384,36,372,48,368,60,372;160,416,160,496,156,508,144,512,132,508,128,496,128,416,132,404,144,400,156,404;256,384,256,464,252,476,240,480,228,476,224,464,224,384,228,372,240,368,252,372;352,416,352,496,348,508,336,512,324,508,320,496,320,416,324,404,336,400,348,404;448,384,448,464,444,476,432,480,420,476,416,464,416,384,420,372,432,368,444,372"},
	SNOWFLAKE = {448,"441,345,448,354,447,366,431,393,422,401,410,399,377,379,383,405,382,416,373,424,358,428,346,426,339,417,320,346,257,310,257,388,310,441,315,452,310,464,299,475,288,480,277,475,257,456,257,496,252,508,241,512,209,512,198,508,193,496,193,456,173,475,162,480,151,475,139,464,134,452,139,442,193,388,193,310,130,346,111,417,104,426,92,428,77,424,68,417,66,405,73,379,40,399,28,401,19,393,3,366,0,354,9,345,43,326,17,319,7,312,6,300,10,285,16,276,29,274,99,293,163,256,99,219,29,238,16,236,10,227,6,212,7,200,17,193,43,186,9,167,0,158,3,146,19,119,28,111,40,113,73,133,67,107,68,96,77,88,92,84,104,86,111,95,130,166,193,202,193,124,139,71,135,60,139,48,151,37,162,31,173,37,193,56,193,16,198,4,209,0,241,0,252,4,257,16,257,56,277,37,288,32,299,37,311,48,315,60,311,71,257,124,257,202,320,166,339,95,346,86,358,84,373,88,382,96,383,107,377,133,410,113,422,111,431,119,447,146,449,158,441,167,407,186,433,193,443,200,444,212,440,227,434,236,421,238,351,219,287,256,351,293,421,274,434,276,440,285,444,300,443,312,433,319,407,326"},
	FONT = {448,"432,416,444,420,448,432,448,464,444,476,432,480,304,480,292,476,288,464,288,432,292,420,304,416,324,416,300,352,148,352,124,416,144,416,156,420,160,432,160,464,156,476,144,480,16,480,4,476,0,464,0,432,4,420,16,416,39,416,170,54,182,38,200,32,248,32,266,38,278,54,409,416;177,272,271,272,224,143"},
	FONT_CASE = {640,"230,86,351,427,352,432,348,444,336,448,285,448,276,445,270,437,251,384,101,384,82,437,76,445,67,448,16,448,4,444,0,432,1,427,122,86,134,70,152,64,200,64,218,70;130,304,222,304,176,175;624,160,636,164,640,176,640,432,636,444,624,448,592,448,580,444,576,432,576,430,544,444,512,448,463,439,422,410,393,369,384,320,384,288,393,239,422,198,463,169,512,160,544,164,576,178,576,176,580,164,592,160;560,320,560,288,556,270,546,254,530,244,512,240,494,244,478,254,468,270,464,288,464,320,468,338,478,354,494,364,512,368,530,364,546,354,556,338"},
	USER_CIRCLE = {496,"72,80,124,40,183,16,248,8,313,16,372,40,424,80,464,132,488,191,496,256,488,321,464,380,424,432,372,472,313,496,248,504,183,496,124,472,72,432,32,380,8,321,0,256,8,191,32,132;310,130,282,110,248,104,214,110,186,130,166,158,160,192,166,226,186,254,214,274,248,280,282,274,310,254,330,226,336,192,330,158;394,380,377,356,354,336,326,324,296,320,289,321,248,328,207,321,200,320,170,324,142,336,119,356,102,380,144,418,192,440,248,448,304,440,352,418"},
	PROJECT_DIAGRAM = {640,"384,320,406,330,416,352,416,480,406,502,384,512,256,512,234,502,224,480,224,352,234,330,256,320;192,32,192,64,416,64,416,128,192,128,192,176,256,288,224,296,201,320,128,192,32,192,10,182,0,160,0,32,10,10,32,0,160,0,182,10;608,0,630,10,640,32,640,160,630,182,608,192,480,192,458,182,448,160,448,32,458,10,480,0"},
	SKULL = {512,"512,224,506,274,487,321,457,363,418,398,406,411,404,428,413,494,410,506,398,512,320,512,320,456,312,448,296,448,288,456,288,512,224,512,224,456,216,448,200,448,192,456,192,512,114,512,102,506,99,494,108,428,106,411,94,398,55,363,25,321,6,274,0,224,8,165,33,112,75,66,128,29,189,7,256,0,323,7,384,29,437,66,479,112,504,165;115,301,136,315,160,320,184,315,205,301,219,280,224,256,219,232,205,211,184,197,160,192,136,197,115,211,101,232,96,256,101,280;307,301,328,315,352,320,376,315,397,301,411,280,416,256,411,232,397,211,376,197,352,192,328,197,307,211,293,232,288,256,293,280"},
	ADJUST = {512,"80,432,40,380,16,321,8,256,16,191,40,132,80,80,132,40,191,16,256,8,321,16,380,40,432,80,472,132,496,191,504,256,496,321,472,380,432,432,380,472,321,496,256,504,191,496,132,472;256,440,304,434,348,416,386,386,416,348,434,304,440,256,434,208,416,164,386,126,348,96,304,78,256,72"},
	TREE = {384,"379,378,385,390,383,402,375,413,362,416,225,416,225,440,255,489,254,504,241,512,145,512,132,504,131,489,161,440,161,416,24,416,11,413,3,402,1,390,7,378,87,288,56,288,43,285,35,275,33,262,38,251,117,160,88,160,75,156,67,146,65,134,71,122,181,5,193,0,205,5,315,122,321,134,319,146,311,156,298,160,269,160,348,251,353,262,351,275,343,285,330,288,299,288"},
	ELLIPSIS_H = {512,"307,205,323,228,328,256,323,284,307,307,284,323,256,328,228,323,205,307,189,284,184,256,189,228,205,205,228,189,256,184,284,189;381,205,404,189,432,184,460,189,483,205,499,228,504,256,499,284,483,307,460,323,432,328,404,323,381,307,365,284,360,256,365,228;29,205,52,189,80,184,108,189,131,205,147,228,152,256,147,284,131,307,108,323,80,328,52,323,29,307,13,284,8,256,13,228"},
	TIMES = {352,"244,256,344,356,353,378,344,401,322,423,299,432,277,423,177,323,77,423,55,432,32,423,10,401,1,378,10,356,110,256,10,156,1,134,10,111,32,89,55,80,77,89,177,189,277,89,299,80,322,89,344,111,353,134,344,156"},
	FILE_IMPORT = {512,"16,288,128,288,128,352,16,352,4,348,0,336,0,304,4,292;505,105,512,122,512,128,384,128,384,0,390,0,407,7;352,136,359,153,376,160,512,160,512,488,505,505,488,512,152,512,135,505,128,488,128,352,256,352,256,417,258,426,266,432,283,428,379,332,385,320,379,308,283,212,266,208,258,214,256,223,256,288,128,288,128,24,135,7,152,0,352,0"},
	USER_MINUS = {640,"624,208,636,212,640,224,640,256,636,268,624,272,432,272,420,268,416,256,416,224,420,212,432,208;314,218,273,247,224,256,175,247,134,218,105,177,96,128,105,79,134,38,175,9,224,0,273,9,314,38,343,79,352,128,343,177;314,288,365,298,408,328,438,371,448,422,448,464,444,482,434,498,418,508,400,512,48,512,30,508,14,498,4,482,0,464,0,422,10,371,40,328,83,298,134,288,151,288,187,300,224,304,261,300,297,288"},
	LIST_ALT = {512,"464,480,48,480,30,476,14,466,4,450,0,432,0,80,4,62,14,46,30,36,48,32,464,32,482,36,498,46,508,62,512,80,512,432,508,450,498,466,482,476;156,132,144,123,128,120,112,123,100,132,91,144,88,160,91,176,100,188,112,197,128,200,144,197,156,188,165,176,168,160,165,144;156,228,144,219,128,216,112,219,100,228,91,240,88,256,91,272,100,284,112,293,128,296,144,293,156,284,165,272,168,256,165,240;156,324,144,315,128,312,112,315,100,324,91,336,88,352,91,368,100,380,112,389,128,392,144,389,156,380,165,368,168,352,165,336;416,176,416,144,413,135,404,132,204,132,195,135,192,144,192,176,195,185,204,188,404,188,413,185;416,272,416,240,413,231,404,228,204,228,195,231,192,240,192,272,195,281,204,284,404,284,413,281;416,368,416,336,413,327,404,324,204,324,195,327,192,336,192,368,195,377,204,380,404,380,413,377"},
	EXPAND_ALT = {448,"213,315,120,408,153,439,160,451,158,465,150,476,136,480,24,480,7,473,0,456,0,344,4,330,15,322,29,320,41,327,72,360,165,267,176,262,187,267,213,293,218,304;235,197,328,104,295,73,288,61,290,47,298,36,312,32,424,32,441,39,448,56,448,168,444,182,433,190,419,192,407,185,376,152,283,245,272,250,261,245,235,219,230,208"},
	TEXT_HEIGHT = {576,"304,32,316,36,320,48,320,144,316,156,304,160,272,160,260,156,256,144,256,112,200,112,200,416,240,416,252,420,256,432,256,464,252,476,240,480,80,480,68,476,64,464,64,432,68,420,80,416,120,416,120,112,64,112,64,144,60,156,48,160,16,160,4,156,0,144,0,48,4,36,16,32;560,368,569,370,575,378,571,395,491,475,480,480,469,475,389,395,385,378,391,370,400,368,448,368,448,144,400,144,391,142,385,134,389,117,469,37,480,32,491,37,571,117,575,134,569,142,560,144,512,144,512,368"},
	TEXT_SIZE = {640,"624,32,636,36,640,48,640,144,636,156,624,160,592,160,580,156,576,144,576,112,488,112,488,416,528,416,540,420,544,432,544,464,540,476,528,480,368,480,356,476,352,464,352,432,356,420,368,416,408,416,408,112,320,112,320,144,316,156,304,160,272,160,260,156,256,144,256,48,260,36,272,32;304,224,316,228,320,240,320,304,316,316,304,320,272,320,260,316,256,304,256,288,200,288,200,416,224,416,236,420,240,432,240,464,236,476,224,480,96,480,84,476,80,464,80,432,84,420,96,416,120,416,120,288,64,288,64,304,60,316,48,320,16,320,4,316,0,304,0,240,4,228,16,224"},
	CLONE = {512,"464,0,482,4,498,14,508,30,512,48,512,336,508,354,498,370,482,380,464,384,176,384,158,380,142,370,132,354,128,336,128,48,132,30,142,14,158,4,176,0;176,416,384,416,384,464,380,482,370,498,354,508,336,512,48,512,30,508,14,498,4,482,0,464,0,176,4,158,14,142,30,132,48,128,96,128,96,336,102,367,120,392,145,410"},
	RULER_TRIANGLE = {512,"502,452,512,470,509,490,496,507,477,512,35,512,10,502,0,477,0,35,10,10,36,0,60,10,111,62,73,100,73,111,84,123,95,123,134,84,190,141,152,179,152,191,163,202,174,202,213,163,269,220,231,258,231,270,242,281,254,281,292,243,349,299,310,338,310,349,321,360,333,360,371,322,428,378,389,417,389,428,401,439,412,439,450,401;128,384,253,384,128,259"},
	FILL_DRIP = {576,"512,320,548,376,569,418,576,448,571,473,558,494,537,507,512,512,487,507,466,494,453,473,448,448,452,428,464,400,496,344;503,217,512,240,503,262,281,484,250,505,213,512,176,505,145,484,28,367,7,336,0,299,7,262,28,231,123,136,37,50,31,39,37,27,59,5,71,-1,82,5,168,91,250,9,272,0,295,9;386,288,435,240,272,77,213,136,272,195,281,218,272,240,250,249,227,240,168,181,87,263,73,276,66,288"},
	COG = {512,"487,316,493,322,493,330,471,380,438,424,424,427,381,402,352,422,320,437,320,486,318,494,311,498,256,504,202,498,194,494,192,486,192,437,160,422,131,402,89,427,74,424,41,380,19,330,25,316,67,291,64,256,67,221,25,196,19,190,19,182,41,132,74,88,89,86,131,110,160,90,192,75,192,26,194,18,201,14,256,8,311,14,318,18,320,26,320,75,352,90,381,110,423,85,438,88,471,132,493,182,493,190,487,196,445,221,445,291;200,312,225,330,256,336,287,330,312,312,330,287,336,256,330,225,312,200,287,182,256,176,225,182,200,200,182,225,176,256,182,287"},
	SHIELD_ALT = {512,"466,84,488,101,496,128,490,204,474,274,449,337,417,388,382,430,346,464,274,508,238,508,197,487,158,458,121,420,87,376,58,325,36,264,21,198,16,128,24,101,46,84,238,4,256,0,274,4;256,446,303,416,345,377,380,328,408,271,425,208,432,139,256,65"},
	SYNC_ALT = {512,"371,133,318,99,256,88,201,97,152,124,115,164,93,215,89,222,81,224,24,224,14,220,12,210,29,155,58,107,98,66,146,34,198,14,256,8,319,16,376,39,427,77,463,41,475,34,489,36,500,44,504,58,504,192,497,209,480,216,346,216,332,212,324,201,322,187,329,175;32,296,166,296,180,300,188,311,190,325,183,337,141,379,194,413,256,424,311,415,360,388,397,348,419,297,423,290,431,288,488,288,498,292,500,302,483,357,454,405,414,446,366,478,314,498,256,504,193,496,136,473,85,435,49,471,37,478,23,476,12,468,8,454,8,320,15,303"},
	MUSIC = {512,"470,2,480,0,502,10,512,32,512,384,505,409,484,430,453,443,416,448,379,443,348,430,327,409,320,384,327,359,348,338,379,325,416,320,448,324,448,139,192,214,192,448,185,473,164,494,133,507,96,512,59,507,28,494,7,473,0,448,7,423,28,402,59,389,96,384,128,388,128,127,134,107,150,96"},
	COPYRIGHT = {512,"80,80,132,40,191,16,256,8,321,16,380,40,432,80,472,132,496,191,504,256,496,321,472,380,432,432,380,472,321,496,256,504,191,496,132,472,80,432,40,380,16,321,8,256,16,191,40,132;373,355,376,347,374,340,349,306,340,302,331,305,322,313,299,326,265,334,234,328,210,310,196,284,191,254,196,224,211,200,234,183,265,178,298,184,327,202,336,205,345,200,367,165,369,159,366,150,354,139,340,131,318,122,263,112,206,122,160,153,129,199,119,255,129,312,160,358,206,390,263,400,323,388,346,377,360,368"},
	COMMENTS = {576,"209,352,151,346,98,327,54,346,9,352,2,347,3,338,22,314,39,284,10,240,1,192,8,150,28,112,62,79,105,53,154,37,209,32,264,37,313,53,356,79,390,112,410,150,417,192,410,234,390,272,356,305,313,331,264,347;539,412,556,442,575,466,576,475,569,480,524,474,480,455,427,474,369,480,308,473,253,453,208,422,177,382,209,384,272,378,328,359,378,328,418,287,441,242,449,192,448,172,500,196,541,230,568,273,577,320,568,368"},
	CLOUD = {640,"538,227,578,242,611,271,633,309,640,352,631,401,602,442,561,471,512,480,144,480,88,470,42,438,10,392,0,336,7,292,27,252,58,220,96,200,96,192,101,150,117,112,143,79,176,53,214,37,256,32,298,38,337,54,370,80,395,112,420,100,448,96,485,103,516,124,537,155,544,192"},
	PLUS = {448,"416,208,438,218,448,240,448,272,438,294,416,304,272,304,272,448,262,470,240,480,208,480,186,470,176,448,176,304,32,304,10,294,0,272,0,240,10,218,32,208,176,208,176,64,186,42,208,32,240,32,262,42,272,64,272,208"},
	TRASH_RESTORE = {448,"53,467,32,128,416,128,395,467,391,484,380,499,365,509,347,512,101,512,83,509,68,499,57,484;123,291,120,310,126,317,135,320,192,320,192,432,196,444,208,448,240,448,252,444,256,432,256,320,313,320,322,317,328,310,325,291,235,197,224,192,213,197;432,32,444,36,448,48,448,80,444,92,432,96,16,96,4,92,0,80,0,48,4,36,16,32,136,32,145,13,154,3,167,0,281,0,294,3,303,13,312,32"},
	CLOUD_UPLOAD_ALT = {640,"538,227,578,242,611,271,633,309,640,352,631,401,602,442,561,471,512,480,144,480,88,470,42,438,10,392,0,336,7,292,27,252,58,220,96,200,96,192,101,150,117,112,143,79,176,53,214,37,256,32,298,38,337,54,370,80,395,112,420,100,448,96,485,103,516,124,537,155,544,192;393,288,402,286,408,278,405,261,299,155,288,150,277,155,171,261,168,278,174,286,183,288,248,288,248,400,252,412,264,416,312,416,324,412,328,400,328,288"},
	SORT_AMOUNT_DOWN = {512,"305,416,316,420,321,432,321,464,316,476,305,480,241,480,230,476,225,464,225,432,230,420,241,416;177,352,186,354,192,362,188,379,108,475,97,480,86,475,6,379,2,362,8,354,17,352,65,352,65,48,70,36,81,32,113,32,124,36,129,48,129,352;433,160,444,164,449,176,449,208,444,220,433,224,241,224,230,220,225,208,225,176,230,164,241,160;369,288,380,292,385,304,385,336,380,348,369,352,241,352,230,348,225,336,225,304,230,292,241,288;497,32,508,36,513,48,513,80,508,92,497,96,241,96,230,92,225,80,225,48,230,36,241,32"},
	GEM = {576,"486,0,576,160,475,160,406,0;358,0,427,160,149,160,218,0;90,0,170,0,101,160,0,160;0,192,101,192,224,444,222,448,219,447;148,192,428,192,291,510,288,512,285,510;352,444,475,192,576,192,357,447,354,448"},
	CLOUD_DOWNLOAD_ALT = {640,"538,227,578,242,611,271,633,309,640,352,631,401,602,442,561,471,512,480,144,480,88,470,42,438,10,392,0,336,7,292,27,252,58,220,96,200,96,192,101,150,117,112,143,79,176,53,214,37,256,32,298,38,337,54,370,80,395,112,420,100,448,96,485,103,516,124,537,155,544,192;405,315,408,298,402,290,393,288,328,288,328,176,324,164,312,160,264,160,252,164,248,176,248,288,183,288,174,290,168,298,171,315,277,421,288,426,299,421"},
	SHARE = {512,"504,190,512,208,504,226,328,378,316,384,302,382,292,373,288,360,288,272,243,274,205,278,146,296,124,311,110,330,101,354,98,383,101,418,111,458,111,469,104,477,83,476,51,447,24,408,6,366,0,322,4,281,15,245,32,215,55,192,83,173,118,158,196,142,288,136,288,56,292,43,302,34,316,32,328,38"},
	COPY = {448,"320,448,320,488,313,505,296,512,24,512,7,505,0,488,0,120,7,103,24,96,96,96,96,392,100,413,112,432,131,444,152,448;320,104,327,121,344,128,448,128,448,392,441,409,424,416,152,416,135,409,128,392,128,24,135,7,152,0,320,0;441,73,448,90,448,96,352,96,352,0,358,0,375,7"},
	TRASH = {448,"432,32,444,36,448,48,448,80,444,92,432,96,16,96,4,92,0,80,0,48,4,36,16,32,136,32,145,13,154,3,167,0,281,0,294,3,303,13,312,32;53,467,32,128,416,128,395,467,391,484,380,499,365,509,347,512,101,512,83,509,68,499,57,484"},
	UNDO = {512,"212,224,12,224,4,220,0,212,0,12,3,3,12,0,60,0,69,3,72,12,72,90,110,55,156,30,205,13,258,8,323,17,382,41,433,82,473,133,497,192,504,256,496,322,472,380,432,432,380,472,321,496,256,504,195,497,140,476,90,440,85,431,89,422,123,388,131,384,140,388,194,421,256,432,302,426,344,409,380,380,409,344,426,302,432,256,426,210,409,168,380,132,344,103,302,86,256,80,214,85,176,100,142,122,114,152,212,152,220,156,224,164,224,212,220,220"},
	CHECK = {512,"174,439,7,273,0,255,7,237,44,201,62,193,80,201,192,313,432,73,450,65,468,73,505,109,512,127,505,145,210,439,192,447"},
	FIRE = {384,"216,24,220,51,234,77,276,124,324,171,347,199,366,234,380,275,384,320,378,370,359,415,328,456,287,487,242,506,192,512,142,506,97,487,56,456,25,415,6,370,0,320,6,270,24,225,55,185,67,178,81,179,92,188,96,202,96,287,101,312,114,333,135,347,159,352,184,347,205,334,219,313,224,288,214,255,192,226,164,199,140,168,128,130,128,107,136,78,150,46,172,11,184,1,199,1,212,9"},
	STAR = {576,"259,18,271,4,288,0,305,4,317,18,382,150,528,172,544,178,554,193,555,211,546,226,440,329,465,475,463,492,452,506,436,512,419,508,288,440,157,508,140,512,124,506,113,492,111,475,136,329,30,226,21,211,22,193,32,178,48,172,194,150"},
	WATER = {576,"562,384,572,390,576,400,576,432,571,444,559,448,518,440,480,422,436,442,385,448,334,442,288,422,244,442,193,448,142,442,96,422,59,440,17,448,5,444,0,432,0,400,4,390,14,384,45,376,71,362,95,352,118,360,151,377,191,384,231,378,264,361,287,352,310,360,343,377,384,384,424,378,456,361,480,353,504,361,531,376;562,240,572,246,576,256,576,288,571,300,559,304,518,296,480,278,436,298,385,304,334,298,288,278,244,298,193,304,142,298,96,278,59,296,17,304,5,300,0,288,0,256,4,246,14,240,45,232,71,218,95,208,118,216,151,233,191,240,231,234,264,217,287,208,310,216,343,233,384,240,424,234,456,217,480,209,504,217,531,232;562,96,572,102,576,112,576,144,571,156,559,160,518,152,480,134,436,154,385,160,334,154,288,134,244,154,193,160,142,154,96,134,59,152,17,160,5,156,0,144,0,112,4,102,14,96,45,88,71,74,95,64,118,72,151,89,191,96,231,90,264,73,287,64,310,72,343,89,384,96,424,90,456,73,480,65,504,73,530,88"},
	PALETTE = {512,"205,5,283,1,356,20,421,58,470,114,502,181,513,255,508,280,494,301,473,315,448,320,368,320,334,328,310,352,299,384,307,418,315,446,309,476,292,499,265,510,217,510,166,496,117,470,74,435,39,389,14,332,1,269,6,203,31,134,76,74,136,30;74,310,97,320,120,310,129,288,120,266,97,256,74,266,65,288;106,182,129,192,152,182,161,160,152,138,129,128,106,138,97,160;234,118,257,128,280,118,289,96,280,74,257,64,234,74,225,96;362,182,385,192,408,182,417,160,408,138,385,128,362,138,353,160"},
	SUN = {512,"189,188,220,167,257,160,294,167,325,188,346,219,353,256,346,293,325,324,294,345,257,352,220,345,189,324,168,293,161,256,168,219;503,240,513,256,503,272,409,319,442,419,438,437,420,441,320,408,272,502,266,510,257,512,241,502,194,408,94,441,76,438,72,419,105,319,11,272,1,256,11,240,105,193,72,93,76,75,94,71,194,104,241,10,257,0,273,10,320,104,420,71,438,75,442,93,409,193;257,384,306,375,348,346,376,305,385,256,376,207,348,166,306,137,257,128,208,137,166,166,138,207,129,256,138,305,166,346,208,375"},
	WAVE_SQUARE = {640,"476,480,324,480,298,470,288,444,288,96,192,96,192,252,182,278,156,288,16,288,4,284,0,272,0,240,4,228,16,224,128,224,128,68,138,42,164,32,316,32,342,42,352,68,352,416,448,416,448,260,458,234,484,224,624,224,636,228,640,240,640,272,636,284,624,288,512,288,512,444,502,470"},
	ATOM = {448,"202,234,225,224,248,234,257,256,248,278,225,288,202,278,193,256;439,128,450,166,441,208,414,256,441,304,450,346,439,384,413,412,375,426,323,426,296,474,263,502,225,512,187,502,154,474,127,426,75,426,37,412,11,384,0,346,9,304,36,256,9,208,0,166,11,128,37,100,75,86,127,86,154,38,187,10,225,0,263,10,296,38,323,86,375,86,413,100;64,352,78,361,108,363,101,323,79,304,64,334;101,189,108,149,105,148,102,148,77,151,64,160,64,178,79,208;191,101,225,114,259,101,242,73,225,64,208,73;259,411,225,398,191,411,208,439,225,448,242,439;168,312,194,330,225,336,256,330,282,312,299,287,305,256,299,225,282,200,256,182,225,176,194,182,168,200,151,225,145,256,151,287;386,352,386,334,371,304,349,323,342,363,372,361;371,208,386,178,386,160,373,151,348,148,345,148,342,149,349,189"},
	CERTIFICATE = {512,"460,256,506,301,512,312,512,324,506,335,495,341,432,357,450,419,450,432,444,443,433,450,420,449,358,431,342,494,336,505,325,512,312,512,302,505,257,459,212,505,202,512,189,512,178,505,172,494,156,431,94,449,81,450,70,443,64,432,64,419,82,357,19,341,8,335,2,324,2,312,8,301,54,256,8,211,2,200,2,188,8,177,19,171,82,155,64,93,64,80,70,69,81,62,94,63,156,81,172,18,178,7,189,0,202,0,212,7,257,54,302,7,313,0,326,1,336,7,342,18,358,81,420,63,433,62,444,69,450,80,450,93,432,155,495,171,506,177,512,188,512,200,506,211"},
	MOUNTAIN = {640,"635,463,640,480,636,495,624,508,608,512,32,512,16,508,4,495,0,480,5,463,293,15,305,4,320,0,335,4,347,15;320,91,218,250,256,288,320,224,405,224"},
	TH = {512,"149,56,149,136,142,153,125,160,24,160,7,153,0,136,0,56,7,39,24,32,125,32,142,39;331,296,324,313,307,320,205,320,188,313,181,296,181,216,188,199,205,192,307,192,324,199,331,216;363,56,370,39,387,32,488,32,505,39,512,56,512,136,505,153,488,160,387,160,370,153,363,136;331,136,324,153,307,160,205,160,188,153,181,136,181,56,188,39,205,32,307,32,324,39,331,56;125,192,142,199,149,216,149,296,142,313,125,320,24,320,7,313,0,296,0,216,7,199,24,192;0,376,7,359,24,352,125,352,142,359,149,376,149,456,142,473,125,480,24,480,7,473,0,456;387,320,370,313,363,296,363,216,370,199,387,192,488,192,505,199,512,216,512,296,505,313,488,320;387,480,370,473,363,456,363,376,370,359,387,352,488,352,505,359,512,376,512,456,505,473,488,480;181,376,188,359,205,352,307,352,324,359,331,376,331,456,324,473,307,480,205,480,188,473,181,456"},
	TH_LARGE = {512,"296,32,488,32,505,39,512,56,512,216,505,233,488,240,296,240,279,233,272,216,272,56,279,39;216,32,233,39,240,56,240,216,233,233,216,240,24,240,7,233,0,216,0,56,7,39,24,32;0,296,7,279,24,272,216,272,233,279,240,296,240,456,233,473,216,480,24,480,7,473,0,456;296,480,279,473,272,456,272,296,279,279,296,272,488,272,505,279,512,296,512,456,505,473,488,480"},
	ROCKET = {512,"505,19,510,56,512,102,504,168,478,224,438,271,384,313,384,417,376,442,357,460,259,509,248,512,231,505,224,488,224,384,202,407,178,416,156,407,105,356,96,332,105,310,128,288,24,288,7,281,0,264,3,253,52,154,70,136,95,128,199,128,241,74,288,34,344,8,410,0,456,2,493,7;356,156,368,165,384,168,400,165,412,156,421,144,424,128,421,112,412,100,400,91,384,88,368,91,356,100,347,112,344,128,347,144"},
	VECTOR_SQUARE = {512,"512,128,502,150,480,160,480,352,502,362,512,384,512,480,502,502,480,512,384,512,362,502,352,480,160,480,150,502,128,512,32,512,10,502,0,480,0,384,10,362,32,352,32,160,10,150,0,128,0,32,10,10,32,0,128,0,150,10,160,32,352,32,362,10,384,0,480,0,502,10,512,32;416,64,416,96,448,96,448,64;64,64,64,96,96,96,96,64;96,448,96,416,64,416,64,448;448,448,448,416,416,416,416,448;416,352,416,160,384,160,362,150,352,128,352,96,160,96,160,128,150,150,128,160,96,160,96,352,128,352,150,362,160,384,160,416,352,416,352,384,362,362,384,352"},
	CLOUD_RAIN = {512,"416,128,453,135,484,156,505,187,512,224,505,261,484,292,453,313,416,320,96,320,59,313,28,292,7,261,0,224,5,194,18,168,40,147,66,133,64,112,72,69,97,33,133,8,176,0,207,4,234,16,258,36,275,61,302,39,336,32,367,38,392,56,410,81,416,112,414,128;88,374,96,368,104,374,127,420,140,443,144,462,140,481,130,498,114,508,96,512,78,508,62,498,52,481,48,462,52,444,65,420;248,374,256,368,264,374,287,420,300,443,304,462,300,481,290,498,274,508,256,512,238,508,222,498,212,481,208,462,212,444,225,420;408,374,416,368,424,374,447,420,460,443,464,462,460,481,450,498,434,508,416,512,398,508,382,498,372,481,368,462,372,444,385,420"},
	BULLSEYE = {496,"72,80,124,40,183,16,248,8,313,16,372,40,424,80,464,132,488,191,496,256,488,321,464,380,424,432,372,472,313,496,248,504,183,496,124,472,72,432,32,380,8,321,0,256,8,191,32,132;118,386,156,416,200,434,248,440,296,434,340,416,378,386,408,348,426,304,432,256,426,208,408,164,378,126,340,96,296,78,248,72,200,78,156,96,118,126,88,164,70,208,64,256,70,304,88,348;158,166,199,137,248,128,297,137,338,166,367,207,376,256,367,305,338,346,297,375,248,384,199,375,158,346,129,305,120,256,129,207;203,301,224,315,248,320,272,315,293,301,307,280,312,256,307,232,293,211,272,197,248,192,224,197,203,211,189,232,184,256,189,280"},
	VOLUME_MUTE = {512,"215,71,227,64,241,66,252,74,256,88,256,424,252,438,241,446,227,448,215,441,126,352,24,352,7,345,0,328,0,184,7,167,24,160,126,160;462,256,507,302,513,313,507,324,484,347,473,353,462,347,416,302,370,347,359,353,348,347,325,324,319,313,325,302,370,256,325,210,319,199,325,188,348,165,359,159,370,165,416,210,462,165,473,159,484,165,507,188,513,199,507,210"},
	MICROPHONE_ALT = {352,"336,192,348,196,352,208,352,256,341,318,308,372,260,411,200,430,200,464,256,464,268,468,272,480,272,496,268,508,256,512,96,512,84,508,80,496,80,480,84,468,96,464,152,464,152,430,111,419,75,399,44,368,11,312,0,248,0,208,4,196,16,192,32,192,44,196,48,208,48,250,56,298,81,340,118,370,163,383,216,378,262,350,294,308,304,256,304,208,308,196,320,192;80,256,80,96,87,59,108,28,139,7,176,0,213,7,244,28,265,59,272,96,187,96,179,98,176,104,176,120,179,126,187,128,272,128,272,160,187,160,179,162,176,168,176,184,179,190,187,192,272,192,272,224,187,224,179,226,176,232,176,248,179,254,187,256,272,256,265,293,244,324,213,345,176,352,139,345,108,324,87,293"},
	FILM = {512,"488,64,505,71,512,88,512,424,505,441,488,448,480,448,480,428,477,419,468,416,428,416,419,419,416,428,416,448,96,448,96,428,93,419,84,416,44,416,35,419,32,428,32,448,24,448,7,441,0,424,0,88,7,71,24,64,32,64,32,84,35,93,44,96,84,96,93,93,96,84,96,64,416,64,416,84,419,93,428,96,468,96,477,93,480,84,480,64;96,372,96,332,93,323,84,320,44,320,35,323,32,332,32,372,35,381,44,384,84,384,93,381;96,276,96,236,93,227,84,224,44,224,35,227,32,236,32,276,35,285,44,288,84,288,93,285;96,180,96,140,93,131,84,128,44,128,35,131,32,140,32,180,35,189,44,192,84,192,93,189;368,388,368,292,365,283,356,280,156,280,147,283,144,292,144,388,147,397,156,400,356,400,365,397;368,220,368,124,365,115,356,112,156,112,147,115,144,124,144,220,147,229,156,232,356,232,365,229;480,372,480,332,477,323,468,320,428,320,419,323,416,332,416,372,419,381,428,384,468,384,477,381;480,276,480,236,477,227,468,224,428,224,419,227,416,236,416,276,419,285,428,288,468,288,477,285;480,180,480,140,477,131,468,128,428,128,419,131,416,140,416,180,419,189,428,192,468,192,477,189"},
	EXTERNAL_LINK_ALT = {512,"432,320,444,324,448,336,448,464,444,482,434,498,418,508,400,512,48,512,30,508,14,498,4,482,0,464,0,112,4,94,14,78,30,68,48,64,208,64,220,68,224,80,224,112,220,124,208,128,64,128,64,448,384,448,384,336,388,324,400,320;488,0,505,7,512,24,512,152,508,166,497,174,483,176,471,169,435,133,192,377,175,384,158,377,135,354,128,337,135,320,379,77,343,41,336,29,338,15,346,4,360,0"},
}


local GlyphCache, RasterCache = {}, {}
local RasterCacheBytes, RasterUse = 0, 0
local RasterCacheLimit = 8 * 1024 * 1024

local function glyphContours(name)
	local cached = GlyphCache[name]
	if cached then return cached end
	local data = assert(GlyphData[name], name)
	local contours, x0, y0, x1, y1 = {}, huge, huge, -huge, -huge
	for part in string.gmatch(data[2], "[^;]+") do
		local c, i = {}, 0
		for number in string.gmatch(part, "-?%d+") do
			i += 1
			local value = tonumber(number)
			c[i] = value
			if i % 2 == 1 then x0, x1 = min(x0, value), max(x1, value) else y0, y1 = min(y0, value), max(y1, value) end
		end
		table.insert(contours, c)
	end
	cached = { adv = data[1], contours = contours, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
	GlyphCache[name] = cached
	return cached
end

local function addSpan(cov, a, b, weight, width)
	if b <= 0 or a >= width then return end
	a, b = max(a, 0), min(b, width)
	local i0, i1 = floor(a), floor(b)
	if i0 == i1 then
		cov[i0] = (cov[i0] or 0) + (b - a) * weight
		return
	end
	cov[i0] = (cov[i0] or 0) + (i0 + 1 - a) * weight
	for i = i0 + 1, i1 - 1 do cov[i] = (cov[i] or 0) + weight end
	if b > i1 then cov[i1] = (cov[i1] or 0) + (b - i1) * weight end
end

local byX = function(a, b) return a[1] < b[1] end

-- contours: lists of x,y in design pixels. device: how many device pixels one design pixel is.
local function rasterize(contours, unit, device, key)
	local k = unit * device
	local edges, minX, minY, maxX, maxY = {}, huge, huge, -huge, -huge
	for _, c in contours do
		local n = #c // 2
		for i = 1, n do
			local x1, y1 = c[i * 2 - 1] * k, c[i * 2] * k
			local j = i % n + 1
			local x2, y2 = c[j * 2 - 1] * k, c[j * 2] * k
			minX, maxX, minY, maxY = min(minX, x1), max(maxX, x1), min(minY, y1), max(maxY, y1)
			if y1 < y2 then
				table.insert(edges, { y1, y2, x1, (x2 - x1) / (y2 - y1), 1 })
			elseif y2 < y1 then
				table.insert(edges, { y2, y1, x2, (x1 - x2) / (y1 - y2), -1 })
			end
		end
	end
	local x0, y0 = floor(minX), floor(minY)
	local width, height = max(ceil(maxX) - x0, 1), max(ceil(maxY) - y0, 1)

	local buf = CanEditableImage and buffer.create(width * height * 4) or nil
	local rects, open = {}, {}
	local SUB = 5
	for row = 0, height - 1 do
		local cov = {}
		for s = 0, SUB - 1 do
			local y = y0 + row + (s + 0.5) / SUB
			local hits = {}
			for _, e in edges do
				if y >= e[1] and y < e[2] then table.insert(hits, { e[3] + (y - e[1]) * e[4], e[5] }) end
			end
			table.sort(hits, byX)
			local winding = 0
			for i = 1, #hits - 1 do
				winding += hits[i][2]
				if winding ~= 0 then addSpan(cov, hits[i][1] - x0, hits[i + 1][1] - x0, 1 / SUB, width) end
			end
		end
		if buf then
			for x = 0, width - 1 do
				local c = cov[x] or 0
				local alpha = round(sat(c) * 255)
				local offset = (row * width + x) * 4
				buffer.writeu8(buf, offset, 255)
				buffer.writeu8(buf, offset + 1, 255)
				buffer.writeu8(buf, offset + 2, 255)
				buffer.writeu8(buf, offset + 3, alpha)
			end
		else
			local nextOpen, x = {}, 0
			while x < width do
				local level = floor(min(cov[x] or 0, 1) * 15 + 0.5)
				local start = x
				repeat x += 1 until x >= width or floor(min(cov[x] or 0, 1) * 15 + 0.5) ~= level
				if level > 0 then
					local runKey = start * 4096 + (x - start) * 16 + level
					local rect = open[runKey]
					if rect then
						rect[4] += 1
					else
						rect = { start, row, x - start, 1, level / 15 }
						table.insert(rects, rect)
					end
					nextOpen[runKey] = rect
				end
			end
			open = nextOpen
		end
	end

	local editableImage = nil
	if buf then
		local ok, img = pcall(function()
			local image = AssetService:CreateEditableImage({ Size = Vector2.new(width, height) })
			image:WritePixelsBuffer(Vector2.zero, Vector2.new(width, height), buf)
			return image
		end)
		if ok and img then
			editableImage = img
		else
			open = {}
			for row = 0, height - 1 do
				local nextOpen, x = {}, 0
				while x < width do
					local offset = (row * width + x) * 4
					local aByte = buffer.readu8(buf, offset + 3)
					local level = round(aByte / 255 * 15)
					local start = x
					repeat
						x += 1
					until x >= width or round((buffer.readu8(buf, (row * width + x) * 4 + 3)) / 255 * 15) ~= level
					if level > 0 then
						local runKey = start * 4096 + (x - start) * 16 + level
						local rect = open[runKey]
						if rect then
							rect[4] += 1
						else
							rect = { start, row, x - start, 1, level / 15 }
							table.insert(rects, rect)
						end
						nextOpen[runKey] = rect
					end
				end
				open = nextOpen
			end
		end
	end

	return { x0 = x0, y0 = y0, w = width, h = height, rects = rects, image = editableImage }
end

local Shapes = setmetatable({}, { __mode = "k" })
local LazyRoots = {}

local function rasterBytes(raster)
	if raster.image then return raster.w * raster.h * 4 end
	return max(#raster.rects * 48, 1)
end

local function rasterInUse(raster)
	for shape in Shapes do
		if shape.raster == raster and shape.holder and shape.holder.Parent then return true end
	end
	return false
end

local function trimRasterCache()
	while RasterCacheBytes > RasterCacheLimit do
		local oldestKey, oldest
		for key, entry in RasterCache do
			if not rasterInUse(entry.raster) and (not oldest or entry.lastUse < oldest.lastUse) then
				oldestKey, oldest = key, entry
			end
		end
		if not oldest then return end
		RasterCache[oldestKey] = nil
		RasterCacheBytes -= oldest.bytes
		if oldest.raster.image then
			pcall(function() oldest.raster.image:Destroy() end)
		end
	end
end

local function cacheRaster(key, raster)
	RasterUse += 1
	local entry = { raster = raster, bytes = rasterBytes(raster), lastUse = RasterUse }
	RasterCache[key] = entry
	RasterCacheBytes += entry.bytes
	return entry
end

local ShapeMeta = {}
ShapeMeta.__index = ShapeMeta

function ShapeMeta:rebuild()
	if self.deferred then return end
	local key = self.key and (self.key .. "@" .. Scale)
	local entry = key and RasterCache[key]
	if entry then
		RasterUse += 1
		entry.lastUse = RasterUse
	else
		local raster = rasterize(self.contours, self.unit, Scale, self.key)
		if key then
			entry = cacheRaster(key, raster)
		else
			entry = { raster = raster }
		end
	end
	local raster = entry.raster
	self.raster = raster
	local holderW, holderH = ceil(raster.w / Scale), ceil(raster.h / Scale)
	setWH(self.holder, holderW, holderH)

	if raster.image then
		for _, frame in self.frames do frame:Destroy() end
		table.clear(self.frames)
		if not self.imageLabel then
			local contentObj
			pcall(function() contentObj = Content.fromObject(raster.image) end)
			local props = {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ImageColor3 = self.color,
				ImageTransparency = 1 - self.alpha,
				Size = UDim2.fromScale(1, 1),
			}
			if contentObj then
				props.ImageContent = contentObj
			else
				props.Image = raster.image
			end
			self.imageLabel = New("ImageLabel", props, self.holder)
			pcall(function()
				if contentObj and self.imageLabel.ImageContent ~= contentObj then
					self.imageLabel.ImageContent = contentObj
				end
			end)
		else
			self.imageLabel.ImageColor3 = self.color
			self.imageLabel.ImageTransparency = 1 - self.alpha
		end
	else
		if self.imageLabel then
			self.imageLabel:Destroy()
			self.imageLabel = nil
		end
		for _, frame in self.frames do frame:Destroy() end
		table.clear(self.frames)
		local deviceW, deviceH = holderW * Scale, holderH * Scale
		for _, r in raster.rects do
			table.insert(self.frames, New("Frame", {
				BorderSizePixel = 0, BackgroundColor3 = self.color,
				BackgroundTransparency = 1 - r[5] * self.alpha,
				Position = UDim2.fromScale(r[1] / deviceW, r[2] / deviceH),
				Size = UDim2.fromScale(r[3] / deviceW, r[4] / deviceH),
			}, self.holder))
		end
	end
	self:at(self.px, self.py)
	trimRasterCache()
end

function ShapeMeta:at(x, y)
	self.px, self.py = x, y
	if self.raster then setXY(self.holder, x + self.raster.x0 / Scale, y + self.raster.y0 / Scale) end
	return self
end

function ShapeMeta:paint(color, alpha)
	alpha = alpha or 1
	if self.color == color and self.alpha == alpha then return self end
	local changed = self.color ~= color
	self.color, self.alpha = color, alpha
	if self.deferred then return self end
	if self.imageLabel then
		if changed then self.imageLabel.ImageColor3 = color end
		self.imageLabel.ImageTransparency = 1 - alpha
		return self
	end
	if self.raster and self.raster.rects then
		for i, frame in self.frames do
			if changed then frame.BackgroundColor3 = color end
			frame.BackgroundTransparency = 1 - self.raster.rects[i][5] * alpha
		end
	end
	return self
end

function ShapeMeta:destroy()
	if self.imageLabel then
		self.imageLabel:Destroy()
		self.imageLabel = nil
	end
	for _, frame in self.frames do frame:Destroy() end
	table.clear(self.frames)
	if self.holder then
		self.holder:Destroy()
		self.holder = nil
	end
	self.raster = nil
	Shapes[self] = nil
	trimRasterCache()
end

-- A glyph is positioned by the centre of its ink, as the original does for nearly every icon.
function ShapeMeta:center(cx, cy)
	return self:at(round(cx - self.inkX), round(cy - self.inkY))
end

function ShapeMeta:setVisible(state) self.holder.Visible = state end

local function Shape(parent, contours, unit, key)
	local shape = setmetatable({
		holder = Box(parent, 0, 0, 0, 0), contours = contours, unit = unit or 1, key = key,
		frames = {}, imageLabel = nil, color = White, alpha = 1, px = 0, py = 0, inkX = 0, inkY = 0,
	}, ShapeMeta)
	Shapes[shape] = true
	local lazy = parent
	while lazy and not LazyRoots[lazy] do lazy = lazy.Parent end
	if lazy then
		shape.deferred = true
		table.insert(LazyRoots[lazy], shape)
	else
		shape:rebuild()
	end
	return shape
end

local function flushLazy(root)
	local pending = LazyRoots[root]
	if not pending then return end
	LazyRoots[root] = nil
	for _, shape in pending do
		shape.deferred = false
		shape:rebuild()
	end
end

local function Glyph(parent, name, size)
	local g = glyphContours(name)
	local unit = size / 512
	local shape = Shape(parent, g.contours, unit, name .. "#" .. size)
	shape.inkX, shape.inkY = (g.x0 + g.x1) * 0.5 * unit, (g.y0 + g.y1) * 0.5 * unit
	shape.boxW = g.adv * unit
	shape.name = name
	return shape
end

-- An anti-aliased polyline with square ends, used for the hand-drawn chevrons and the check.
local function strokeContours(points, thickness)
	local contours, half = {}, thickness * 0.5
	for i = 1, #points - 2, 2 do
		local x1, y1, x2, y2 = points[i], points[i + 1], points[i + 2], points[i + 3]
		local dx, dy = x2 - x1, y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)
		local nx, ny = -dy / length * half, dx / length * half
		-- extended by half the width so that the joints overlap
		local ex, ey = dx / length * half, dy / length * half
		local a, b = { x1 - ex + nx, y1 - ey + ny }, { x2 + ex + nx, y2 + ey + ny }
		local c, d = { x2 + ex - nx, y2 + ey - ny }, { x1 - ex - nx, y1 - ey - ny }
		table.insert(contours, { a[1], a[2], b[1], b[2], c[1], c[2], d[1], d[2] })
	end
	return contours
end

local function setRasterScale(scale)
	assert(type(scale) == "number" and scale == scale and scale >= 0.5 and scale <= 2, "Scale must be a finite number between 0.5 and 2")
	Scale = scale
	StageScale.Scale = scale
	Stage.Size = UDim2.fromScale(1 / scale, 1 / scale)
	table.clear(Widths)
	table.clear(WidthKeys)
	WidthCount, WidthCursor = 0, 1
	for shape in Shapes do
		if shape.holder.Parent then shape:rebuild() end
	end
	Root:invalidateGrid(true)
end

local function repaintAll()
	applyPalette()
	Root:refresh()
end

--[[ ---------------------------------------- Text ------------------------------------------ ]]

-- From the live client: Inter's capitals start 2px below a Top-aligned label's top edge.
local CapCentre = { [9] = 5, [10] = 5.5, [11] = 6, [12] = 6.4, [14] = 7.5 }

-- Top of a label whose capitals are centred on cy.
local function capY(cy, size)
	return round(cy - CapCentre[size])
end

local function Label(parent, text, x, y, size, font, color)
	return New("TextLabel", {
		Text = text, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(max(measure(text, size, font) + 4, 4), ceil(size * 1.3)),
		BackgroundTransparency = 1, BorderSizePixel = 0, FontFace = font or FontMedium, TextSize = size,
		TextColor3 = color or White, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	}, parent)
end

local function setText(label, text, size, font)
	if label.Text ~= text then
		label.Text = text
		label.Size = UDim2.fromOffset(max(measure(text, size, font) + 4, 4), label.Size.Y.Offset)
	end
end

-- A label held to a rectangle. If it overflows it fades at the edge and creeps along while hovered.
local function ScrollText(parent, x, y, w, h, size, font, owner)
	local clip = Box(parent, x, y, w, h)
	clip.ClipsDescendants = true
	local label = Label(clip, "", 0, capY(h * 0.5, size), size, font)
	local object = { clip = clip, label = label, scroll = 0, over = 0, hovered = false, text = nil, wait = 0, widthValue = w }
	local fade = New("UIGradient", { Enabled = false }, label)

	local function refreshFade()
		label.Position = UDim2.fromOffset(-round(object.scroll), label.Position.Y.Offset)
		if object.over <= 0 then
			fade.Enabled = false
			return
		end
		local width = object.textW
		local rectW = clip.Size.X.Offset
		local band = min(18, rectW * 0.4)
		local left, right = sat(object.scroll / band), sat((object.over - object.scroll) / band)
		local a0 = object.scroll / width
		local a1 = (object.scroll + band) / width
		local b0 = (object.scroll + rectW - band) / width
		local b1 = (object.scroll + rectW) / width
		local keys = { NumberSequenceKeypoint.new(0, left > 0 and 1 or 0) }
		local function add(t, v)
			t = clamp(t, 0.0001, 0.9999)
			if t > keys[#keys].Time + 0.0005 then table.insert(keys, NumberSequenceKeypoint.new(t, v)) end
		end
		add(a0, left)
		add(a1, 0)
		add(b0, 0)
		add(b1, right)
		table.insert(keys, NumberSequenceKeypoint.new(1, right > 0 and 1 or 0))
		fade.Transparency = NumberSequence.new(keys)
		fade.Enabled = true
	end

	local ticking = false
	local function ensureTicker()
		if ticking then return end
		ticking = true
		Run(function(dt)
			if object.over > 0 and object.hovered then
				object.wait += dt
				if object.wait >= 0.25 then object.scroll = min(object.over, object.scroll + 40 * dt) end
			else
				object.wait = 0
				object.scroll += (0 - object.scroll) * (1 - exp(-14 * dt))
				if object.scroll < 0.01 then object.scroll = 0 end
			end
			refreshFade()
			if object.scroll == 0 and not object.hovered then
				ticking = false
				return false
			end
			return true
		end, owner)
	end
	local function syncWidth()
		local width = clip.Size.X.Offset
		if object.widthValue ~= width then
			object.widthValue = width
			object.over = object.textW and max(0, object.textW - width) or 0
			object.scroll = min(object.scroll, object.over)
			refreshFade()
		end
	end

	function object:set(text)
		if self.text == text then return end
		self.text = text
		setText(label, text, size, font)
		self.textW = max(measure(text, size, font), 1)
		self.widthValue = clip.Size.X.Offset
		self.over = max(0, self.textW - self.widthValue)
		self.scroll = 0
		refreshFade()
	end
	function object:paint(color, alpha)
		label.TextColor3 = color
		label.TextTransparency = 1 - alpha
	end
	function object:hover(state)
		syncWidth()
		self.hovered = state
		if self.over > 0 then ensureTicker() end
	end
	function object:width(w2)
		setWH(clip, w2, h)
		self.widthValue = w2
		if self.textW then
			self.over = max(0, self.textW - w2)
			refreshFade()
		end
	end
	return object
end

--[[ ---------------------------------------- Popup cards ----------------------------------- ]]

local CurrentWindow
local ZCounter = 100
local function nextZ() ZCounter += 1 return ZCounter end

local Card = {}
Card.__index = Card

local function buildSurface(frame, width, height, rounding, border)
	local surface = Box(frame, 0, 0, width, height, T.Popup, rounding)
	local shadow = Shadow(surface, 26, 0.5, 6)
	local ring
	if border then
		ring = Stroke(Box(frame, 1, 1, width - 2, height - 2, nil, max(rounding - 1, 0)), T.PopupBorder)
	end
	-- Task 3.1: Specular rim lighting stroke with vertical gradient
	local rimFrame = Box(frame, 1, 1, width - 2, height - 2, nil, max(rounding - 1, 0))
	local rimStroke = Stroke(rimFrame, White, 1)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(1, 1.0),
		}),
	}, rimStroke)
	local topInset = max(2, min(rounding, floor(width * 0.25)))
	local topGlow = Box(frame, topInset, 1, max(width - topInset * 2, 1), 2, Accent, 1)
	return surface, shadow, ring, topGlow, rimStroke, topInset
end

local function resizeSurface(card, width, height)
	setWH(card.surface, width, height)
	if card.ring then setWH(card.ring.Parent, width - 2, height - 2) end
	if card.topGlow then
		local inset = card.topGlowInset or 2
		setXY(card.topGlow, inset, 1)
		setWH(card.topGlow, max(width - inset * 2, 1), 2)
	end
	if card.rimStroke then setWH(card.rimStroke.Parent, width - 2, height - 2) end
	setWH(card.frame, width, height)
end

function Card:paintSurface()
	local a = self.scope.alpha
	self.surface.BackgroundColor3, self.surface.BackgroundTransparency = T.Popup, 1 - a
	if self.shadow then self.shadow.Transparency = 1 - 0.5 * a end
	if self.ring then
		self.ring.Color = T.PopupBorder
		self.ring.Transparency = 1 - a
	end
	if self.topGlow then
		self.topGlow.BackgroundColor3 = Accent
		self.topGlow.BackgroundTransparency = 1 - a
	end
	if self.rimStroke then
		self.rimStroke.Transparency = 1 - a
	end
end

local function newCard(o)
	local width, padding = o.width or 240, o.padding or 10
	local rounding = o.rounding or 12
	local frame = Box(Stage, 0, 0, width, 40)
	frame.Visible, frame.Active, frame.Name = false, true, o.name or "Card"
	local surface, shadow, ring, topGlow, rimStroke, topGlowInset = buildSurface(frame, width, 40, rounding, o.border ~= false)
	local content = Box(frame, 0, 0, width, 40)
	local card = setmetatable({
		frame = frame, surface = surface, shadow = shadow, ring = ring, topGlow = topGlow, topGlowInset = topGlowInset, rimStroke = rimStroke, content = content,
		width = width, height = 40, padding = padding, build = o.build, place = o.place,
		scope = newScope(Root), state = 0, isOpen = false, built = false, base = Vector2.zero, drag = Vector2.zero, dragTarget = Vector2.zero,
	}, Card)
	card.scope.own = 0
	card.scope:paint(function() card:paintSurface() end)
	return card
end

function Card:setHeight(height)
	self.height = height
	resizeSurface(self, self.width, height)
	setWH(self.content, self.width, height)
	self:paintSurface()
end

function Card:apply()
	local p = self.base + self.drag
	setXY(self.frame, round(p.X), round(p.Y))
	self.scope:invalidateGrid(true)
	self:paintSurface()
end

function Card:dragTo(target)
	self.dragTarget = target
	if self.dragging then return end
	self.dragging = true
	Run(function(dt)
		self.drag = self.drag:Lerp(self.dragTarget, 1 - exp(-20 * dt))
		if (self.dragTarget - self.drag).Magnitude < 0.5 then self.drag = self.dragTarget end
		self:apply()
		if self.drag == self.dragTarget then
			self.dragging = false
			return false
		end
		return true
	end, self.scope)
end

function Card:startFade()
	if self.fading then return end
	self.fading = true
	Run(function(dt)
		local value = self.state
		if self.isOpen then
			value += (1 - value) * (1 - exp(-15 * dt))
			if value > 0.998 then value = 1 end
		else
			value = max(0, value - dt / 0.16)
			if value < 0.01 then value = 0 end
		end
		self.state = value
		self.scope:setAlpha(value)
		if value == 0 then self.frame.Visible = false end
		if (self.isOpen and value == 1) or value == 0 then
			self.fading = false
			return false
		end
		return true
	end, self.scope)
end

function Card:open(level, ...)
	closePopupsTo(level or 0)
	self.level = #Popups + 1
	if not self.built then
		self.built = true
		if self.build then self.build(self) end
	end
	if self.onOpen then self.onOpen(...) end
	self.drag, self.dragTarget = Vector2.zero, Vector2.zero
	if self.place then self.base = self.place(self, ...) end
	self.isOpen = true
	table.insert(Popups, self)
	self.frame.ZIndex = nextZ()
	self.frame.Visible = true
	self:apply()
	self:startFade()
	if self.onState then self.onState(true) end
end

function Card:close()
	self.isOpen = false
	self:startFade()
	if self.onState then self.onState(false) end
end

function Card:destroy()
	if self.isOpen then closePopupsTo((self.level or 1) - 1) end
	if self.scope and self.scope.destroy then
		self.scope:destroy()
	else
		local index = table.find(Root.kids, self.scope)
		if index then table.remove(Root.kids, index) end
	end
	self.frame:Destroy()
	trimRasterCache()
end

closePopupsTo = function(level)
	for i = #Popups, level + 1, -1 do
		local card = table.remove(Popups, i)
		card:close()
	end
end

local function keepOnScreen(card, x, y, margin)
	margin = margin or 10
	local view = viewport()
	return Vector2.new(clamp(x, margin, max(margin, view.X - card.width - margin)), clamp(y, margin, max(margin, view.Y - card.height - margin)))
end

-- Beside the click, centred on its row, outside the menu when there is room.
local function placeBeside(card, click)
	local x, y = click.X + 45, click.Y
	if CurrentWindow then
		local a = CurrentWindow:pos()
		local top, bottom = a.Y, a.Y + 600
		y = clamp(y, top + 16 + card.height * 0.5, max(top + 16 + card.height * 0.5, bottom - 16 - card.height * 0.5))
	end
	return keepOnScreen(card, x, y - card.height * 0.5)
end

--[[ ---------------------------------------- Tooltip --------------------------------------- ]]

local TipFrame, TipTitle, TipBody, TipOwner, TipCard
local TipAlpha = 0

local function buildTip()
	TipCard = newCard({ width = 200, rounding = 10, name = "Tooltip" })
	TipCard.frame.Active = false
	TipFrame = TipCard.frame
	TipTitle = Label(TipCard.content, "", 14, capY(20.5, 14), 14, FontSemi)
	TipBody = Label(TipCard.content, "", 14, capY(44.5, 12), 12)
	TipCard.scope:paint(function()
		local a = TipCard.scope.alpha
		TipTitle.TextColor3, TipTitle.TextTransparency = T.Text, 1 - a
		TipBody.TextColor3, TipBody.TextTransparency = T.Soft, 1 - a
	end)
end

local function runTip()
	Run(function(dt)
		local showing = TipOwner ~= nil
		TipAlpha = showing and min(1, TipAlpha + dt / 0.12) or max(0, TipAlpha - dt / 0.14)
		TipCard.scope:setAlpha(TipAlpha)
		if TipAlpha == 0 then
			TipFrame.Visible = false
			Tip.running = false
			return false
		end
		return true
	end, TipCard.scope)
end

ShowTip = function(item)
	if TipOwner == item then return end
	if not TipFrame then buildTip() end
	TipOwner = item
	local title, body = tr(item.tip[1]), tr(item.tip[2])
	TipTitle.Text, TipBody.Text = title, body
	local titleW, bodyW = measure(title, 14, FontSemi), measure(body, 12)
	local lines = bodyW > 320 and ceil(bodyW / 320) or 1
	local width = ceil(max(titleW, min(bodyW, 320))) + 28
	TipBody.TextWrapped = lines > 1
	setWH(TipTitle, titleW + 4, 18)
	setWH(TipBody, min(bodyW, 320) + 2, lines * 15 + 2)
	TipCard.width = width
	TipCard.height = 12 + 17 + 8 + lines * 15 + 12
	resizeSurface(TipCard, width, TipCard.height)
	setWH(TipCard.content, width, TipCard.height)
	local a = toStage(item.gui.AbsolutePosition)
	local s = item.gui.AbsoluteSize / Scale
	local spot = keepOnScreen(TipCard, a.X + s.X + 30, a.Y, 6)
	setXY(TipFrame, round(spot.X), round(spot.Y))
	TipFrame.ZIndex = 100000
	TipFrame.Visible = true
	TipCard:paintSurface()
	if not Tip.running then
		Tip.running = true
		runTip()
	end
end

HideTip = function()
	TipOwner = nil
end

--[[ ---------------------------------------- Small parts ----------------------------------- ]]

local function Switch(parent, x, y, scope)
	local track = Box(parent, x, y, 30, 19, White, 9)
	track:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local rimFrame = Box(track, 1, 1, 28, 17, nil, 8)
	rimFrame:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local rim = Stroke(rimFrame)
	local knob = Box(track, 2, 2, 15, 15, White, 8)
	knob:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	return function(t)
		t = sat(t)
		local a = scope.alpha
		track.BackgroundColor3 = T.SwitchOff:Lerp(Accent, t)
		track.BackgroundTransparency = 1 - a
		rim.Color, rim.Transparency = T.SwitchRim, 1 - A.SwitchRim * (1 - t) * a
		setXY(knob, round(2 + 11 * t), 2)
		knob.BackgroundColor3 = T.KnobOff:Lerp(White, t)
		knob.BackgroundTransparency = 1 - a
	end
end

-- A 4px bar on a half pixel, as ImGui rasterises it: half coverage on the rows either side.
local function SoftBar(parent, x, y, w, color, corners)
	local bar = Box(parent, x, y, w, 5, color, 2)
	local g = New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(.199, .5), NumberSequenceKeypoint.new(.2, 0),
			NumberSequenceKeypoint.new(.799, 0), NumberSequenceKeypoint.new(.8, .5), NumberSequenceKeypoint.new(1, .5),
		}),
	}, bar)
	return bar, g
end

local function circle(frame)
	frame:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	return frame
end

--[[ ---------------------------------------- Colours --------------------------------------- ]]

local function newColor(c, alpha, c2, alpha2, gradient)
	return { a = c, aa = alpha or 1, b = c2 or c, ba = alpha2 or alpha or 1, gradient = gradient or false }
end
Library.Color = newColor

local function Preview(parent, x, y, size, radius, scope)
	local base = Box(parent, x, y, size, size, Color3.fromRGB(204, 204, 204), radius)
	local cell = max(2, size / 3)
	local checks = {}
	for row = 0, 2 do
		for col = 0, 2 do
			if (row + col) % 2 == 1 then
				local px, py = floor(col * cell), floor(row * cell)
				table.insert(checks, Box(base, px, py, ceil(cell), ceil(cell), Color3.fromRGB(128, 128, 128)))
			end
		end
	end
	local fill = Box(base, 0, 0, size, size, White, radius)
	local grad = New("UIGradient", {}, fill)
	local lineFrame = Box(base, 1, 1, size - 2, size - 2, nil, max(radius - 1, 1))
	local line = Stroke(lineFrame)
	return base, function(value, alpha)
		alpha = alpha or scope.alpha
		local c1, a1 = value.gradient and value.b or value.a, value.gradient and value.ba or value.aa
		local clear = value.aa < 1 or a1 < 1
		base.BackgroundTransparency = clear and 1 - alpha or 1
		for _, f in checks do f.BackgroundTransparency = clear and 1 - alpha or 1 end
		fill.BackgroundTransparency = 1 - alpha
		grad.Color = ColorSequence.new(value.a, c1)
		grad.Transparency = NumberSequence.new(1 - value.aa, 1 - a1)
		line.Color, line.Transparency = T.SwatchLine, 1 - A.SwatchLine * alpha
	end
end

local function encodeColor(col)
	return { c = toHex(col.a), a = col.aa, c2 = toHex(col.b), a2 = col.ba, g = col.gradient }
end

local function decodeColor(col, data)
	if type(data) ~= "table" then return end
	col.a = fromHex(data.c) or col.a
	col.b = fromHex(data.c2) or col.b
	col.aa, col.ba = tonumber(data.a) or col.aa, tonumber(data.a2) or col.ba
	col.gradient = data.g == true
end

local function hsv(color)
	local h, s, v = color:ToHSV()
	return h, s, v
end

local function hexOf(c, a)
	return string.format("%02X%02X%02X%02X", round(c.R * 255), round(c.G * 255), round(c.B * 255), round(a * 255))
end

-- Builds the picker's controls into a card. Returns the y the extras start at.
local function buildPicker(flow, slots, allowGradient, onChange, onSlot)
	local card, parent, scope = flow.card, flow.parent, flow.scope
	local p0, y0, w = flow.x, flow.y, flow.w
	local slot = 1
	local mode = 0
	local states = {}
	local function state(i)
		local st = states[i]
		if not st then
			st = { h = { 0, 0 }, s = { 0, 0 }, v = { 1, 1 }, stop = 1, grab = nil, synced = {} }
			states[i] = st
		end
		return st
	end
	local redraw
	local view = { init = false, h = 0, a = 1, grad = 0, s = { 0, 0 }, v = { 1, 1 } }

	local top = y0
	local chipFrames, ring, nameLabel
	if #slots > 1 then
		local row_w = #slots * 16 + (#slots - 1) * 9
		local x0 = p0 + round((w - row_w) * 0.5)
		local cy = y0 + 16 + 8
		nameLabel = Box(parent, p0, y0, w, 18)
		nameLabel = New("TextLabel", {
			Text = "", Size = UDim2.fromOffset(w, 18), BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
		}, nameLabel)
		ring = Box(parent, x0 - 3, cy - 3, 22, 22, nil, 6)
		local ringStroke = Stroke(ring, Accent, 1.5)
		chipFrames = {}
		for i, s in slots do
			local cx = x0 + (i - 1) * 25
			local base, paintPreview = Preview(parent, cx, cy, 16, 4, scope)
			local hoverRing = Box(parent, cx - 2, cy - 2, 20, 20, nil, 6)
			local hoverStroke = Stroke(hoverRing, T.Text)
			local ht = Anim(0, 14)
			local function paint()
				paintPreview(s.value)
				hoverStroke.Color, hoverStroke.Transparency = T.Text, 1 - 0.25 * ht.v * scope.alpha
			end
			ht.cb = paint
			scope:paint(paint)
			chipFrames[i] = paint
			Hit(scope, base, {
				hover = function(b) ht:to((b and i ~= slot) and 1 or 0) end,
				click = function()
					slot = i
					setXY(ring, x0 + (i - 1) * 25 - 3, cy - 3)
					nameLabel.Text = tr(slots[i].name or "")
					view.init = false
					if onSlot then onSlot(i) end
					redraw()
				end,
			})
		end
		scope:paint(function()
			ringStroke.Color, ringStroke.Transparency = Accent, 1 - scope.alpha
			nameLabel.TextColor3, nameLabel.TextTransparency = T.Text, 1 - scope.alpha
			nameLabel.Text = tr(slots[slot].name or "")
		end)
		top = cy + 16 + 16
	end

	local svH = round(w * 0.82)
	local sv = Box(parent, p0, top, w, svH, White, 8)
	local svColor = New("UIGradient", {}, sv)
	local svBlack = Box(parent, p0, top, w, svH, Black, 8)
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, svBlack)

	local function knob(radius)
		local outer = circle(Box(parent, 0, 0, radius * 2, radius * 2, White, 1))
		local shadow = Shadow(outer, 5, 0.55, 1)
		local inner = circle(Box(parent, 0, 0, (radius - 2) * 2, (radius - 2) * 2, White, 1))
		return function(x, y, fill, alpha)
			x, y = round(x), round(y)
			setXY(outer, x - radius, y - radius)
			setXY(inner, x - radius + 2, y - radius + 2)
			outer.BackgroundTransparency = 1 - alpha
			if shadow then shadow.Transparency = 1 - 0.45 * alpha end
			inner.BackgroundColor3, inner.BackgroundTransparency = fill, 1 - alpha
		end
	end

	local link = Box(parent, 0, 0, 0, 0, White)
	local linkShadow = Shadow(link, 3, 0.6, 0)
	local otherKnob = knob(6)
	local mainKnob = knob(7)

	local hueY = top + svH + 14
	local hueBar = Box(parent, p0, hueY, w, 8, White, 4)
	New("UIGradient", { Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)), ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)), ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 1, 1)),
	}) }, hueBar)
	local huePill = Box(parent, 0, hueY - 4, 7, 16, White, 3)
	local hueShadow = Shadow(huePill, 4, 0.65, 1)
	local hueFill = Box(huePill, 1, 1, 5, 14, White, 2)
	local hueHit = Box(parent, p0, hueY - 5, w, 18)

	local alphaY = hueY + 8 + 12
	local alphaBase = Box(parent, p0, alphaY, w, 8, Color3.fromRGB(204, 204, 204), 4)
	local alphaChecks = {}
	for col = 1, floor(w / 4) - 2 do
		for row = 0, 1 do
			if (col + row) % 2 == 1 then
				table.insert(alphaChecks, Box(alphaBase, col * 4, row * 4, 4, 4, Color3.fromRGB(128, 128, 128)))
			end
		end
	end
	local alphaFill = Box(parent, p0, alphaY, w, 8, White, 4)
	local alphaGrad = New("UIGradient", { Transparency = NumberSequence.new(1, 0) }, alphaFill)
	local alphaKnob = circle(Box(parent, 0, alphaY - 2, 12, 12, White, 1))
	local alphaKnobShadow = Shadow(alphaKnob, 4, 0.6, 1)
	local alphaHit = Box(parent, p0, alphaY - 5, w, 18)

	local ry = alphaY + 8 + 14
	local rowH = 26
	local fmtChevron = Glyph(parent, "CHEVRON_DOWN", 11)
	local fmtLabel = Label(parent, "HEX", round(p0 + fmtChevron.boxW + 5), capY(ry + 13, 11), 11)
	local fmtHit = Box(parent, p0, ry, round(fmtChevron.boxW + 5 + measure("HEX", 11) + 4), rowH)
	local fmtWidth = fmtChevron.boxW + 5 + measure("HEX", 11)
	local btnW = allowGradient and 22 or 0
	local btnX = p0 + w - btnW
	local pctW = 44
	local pctX = btnX - (allowGradient and 6 or 0) - pctW
	local valX = p0 + fmtWidth + 12
	local valW = max(40, pctX - 6 - valX)
	fmtChevron:center(p0 + fmtChevron.boxW * 0.5, ry + 13)
	local valBox = Box(parent, valX, ry, valW, rowH, White, 6)
	local _, previewPaint = Preview(parent, valX + 8, ry + 7, 12, 3, scope)
	local hash = Label(parent, "#", valX + 8 + 12 + 7, capY(ry + 13, 11), 11)
	local textX = valX + 8 + 12 + 7 + measure("#", 11) + 1
	local input = New("TextBox", {
		Text = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(textX, capY(ry + 13, 11)), Size = UDim2.fromOffset(valX + valW - 8 - textX, 15),
		ClipsDescendants = true,
	}, parent)
	local pctBox = Box(parent, pctX, ry, pctW, rowH, White, 6)
	local pctInput = New("TextBox", {
		Text = "100%", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(pctX, capY(ry + 13, 11)), Size = UDim2.fromOffset(pctW, 15),
	}, parent)
	local gradIcon, gradT
	if allowGradient then
		gradIcon = Glyph(parent, "ADJUST", 13)
		gradIcon:center(btnX + btnW * 0.5, ry + 13)
		gradT = Anim(0, 15)
	end
	local fmtT = Anim(0, 15)

	local function current() return slots[slot].value end
	local function stops(col, i)
		if i == 1 then return col.a, col.aa end
		return col.b, col.ba
	end
	local function setStop(col, i, c, a)
		if i == 1 then col.a, col.aa = c, a else col.b, col.ba = c, a end
	end
	local function sync()
		local st, col = state(slot), current()
		for i = 1, 2 do
			local c, a = stops(col, i)
			local key = hexOf(c, a)
			if st.synced[i] ~= key then
				local h, s, v = hsv(c)
				if s > 0 and v > 0 then st.h[i] = h end
				if v > 0 then st.s[i] = s end
				st.v[i] = v
				st.synced[i] = key
			end
		end
		if not col.gradient then st.stop = 1 end
	end
	local function commit(i)
		local st, col = state(slot), current()
		local c = Color3.fromHSV(st.h[i], st.s[i], st.v[i])
		local _, a = stops(col, i)
		setStop(col, i, c, a)
		st.synced[i] = hexOf(c, a)
		if onChange then onChange(col) end
	end
	local function startGradient(s, v)
		local st, col = state(slot), current()
		col.gradient = true
		st.h[2], st.s[2], st.v[2] = st.h[1], s, v
		col.ba = col.aa
		commit(2)
		st.stop = 2
	end

	local writingInputs = false
	local dragging = false
	local viewTicking = false

	local function drawNow()
		local st, col = state(slot), current()
		local a = scope.alpha
		local d = st.stop
		local svX = function(i) return p0 + view.s[i] * w end
		local svY = function(i) return top + (1 - view.v[i]) * svH end
		local hueColor = Color3.fromHSV(view.h, 1, 1)
		svColor.Color = ColorSequence.new(White, hueColor)
		sv.BackgroundTransparency, svBlack.BackgroundTransparency = 1 - a, 1 - a
		local shown = Color3.fromHSV(view.h, view.s[d], view.v[d])
		mainKnob(svX(d), svY(d), shown, a)
		otherKnob(svX(3 - d), svY(3 - d), select(1, stops(col, 3 - d)), a * view.grad)
		local x1, y1, x2, y2 = svX(1), svY(1), svX(2), svY(2)
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		if view.grad > 0.01 and len > 14 then
			link.Visible = true
			link.Size = UDim2.fromOffset(round(len - 14), 2)
			link.AnchorPoint = Vector2.new(0.5, 0.5)
			link.Position = UDim2.fromOffset(round((x1 + x2) * 0.5), round((y1 + y2) * 0.5))
			link.Rotation = math.deg(math.atan2(dy, dx))
			link.BackgroundTransparency = 1 - 0.95 * view.grad * a
			if linkShadow then linkShadow.Transparency = 1 - 0.4 * view.grad * a end
		else
			link.Visible = false
		end

		hueBar.BackgroundTransparency = 1 - a
		local hx = clamp(p0 + view.h * w, p0 + 3.5, p0 + w - 3.5)
		setXY(huePill, round(hx - 3.5), hueY - 4)
		huePill.BackgroundTransparency = 1 - a
		if hueShadow then hueShadow.Transparency = 1 - 0.35 * a end
		hueFill.BackgroundColor3, hueFill.BackgroundTransparency = hueColor, 1 - a

		alphaBase.BackgroundTransparency = 1 - a
		for _, f in alphaChecks do f.BackgroundTransparency = 1 - a end
		alphaFill.BackgroundColor3, alphaFill.BackgroundTransparency = shown, 1 - a
		local ax = clamp(p0 + view.a * w, p0 + 6, p0 + w - 6)
		setXY(alphaKnob, round(ax - 6), alphaY - 2)
		alphaKnob.BackgroundTransparency = 1 - a
		if alphaKnobShadow then alphaKnobShadow.Transparency = 1 - 0.4 * a end

		local fmtCol = T.Disabled:Lerp(T.Text, fmtT.v)
		fmtChevron:paint(fmtCol, a)
		fmtLabel.TextColor3, fmtLabel.TextTransparency = fmtCol, 1 - a
		fmtLabel.Text = mode == 0 and "HEX" or "RGB"
		valBox.BackgroundColor3, valBox.BackgroundTransparency = T.FieldBg, 1 - A.FieldBg * a
		pctBox.BackgroundColor3, pctBox.BackgroundTransparency = T.FieldBg, 1 - A.FieldBg * a
		previewPaint(col, a)
		hash.TextColor3, hash.TextTransparency = T.Disabled, (mode == 0) and 1 - a or 1
		input.TextColor3, input.TextTransparency = T.Text, 1 - a
		pctInput.TextColor3, pctInput.TextTransparency = T.Text, 1 - a
		if gradIcon then gradIcon:paint(col.gradient and Accent or T.Disabled:Lerp(T.Text, gradT.v), a) end
		if chipFrames then chipFrames[slot]() end
	end

	redraw = function()
		sync()
		local st, col = state(slot), current()
		local d = st.stop
		local c, ca = stops(col, d)
		writingInputs = true
		if not input:IsFocused() then
			input.Text = mode == 0 and hexOf(c, ca) or string.format("%d, %d, %d", round(c.R * 255), round(c.G * 255), round(c.B * 255))
		end
		if not pctInput:IsFocused() then pctInput.Text = round(ca * 100) .. "%" end
		writingInputs = false
		local gradTarget = col.gradient and 1 or 0
		if not view.init or dragging then
			view.h, view.a = st.h[d], ca
			for i = 1, 2 do view.s[i], view.v[i] = st.s[i], st.v[i] end
			if not view.init then view.grad = gradTarget end
			view.init = true
			if dragging then view.grad = gradTarget end
			drawNow()
			return
		end
		if viewTicking then return end
		viewTicking = true
		Run(function(dt)
			local ease = 1 - exp(-18 * dt)
			local st2, col2 = state(slot), current()
			local d2 = st2.stop
			local _, ca2 = stops(col2, d2)
			local dh = st2.h[d2] - view.h
			if dh > 0.5 then dh -= 1 elseif dh < -0.5 then dh += 1 end
			view.h = (view.h + dh * ease) % 1
			if abs(dh) < 0.0005 then view.h = st2.h[d2] end
			local settled = abs(dh) < 0.0005
			local function approach(value, target)
				local nextValue = value + (target - value) * ease
				if abs(target - nextValue) < 0.0005 then return target end
				settled = false
				return nextValue
			end
			view.a = approach(view.a, ca2)
			for i = 1, 2 do view.s[i] = approach(view.s[i], st2.s[i]); view.v[i] = approach(view.v[i], st2.v[i]) end
			view.grad = approach(view.grad, col2.gradient and 1 or 0)
			drawNow()
			if settled then
				viewTicking = false
				return false
			end
			return true
		end, scope)
	end

	local function fieldValues(point)
		local at = toStage(point) - toStage(sv.AbsolutePosition)
		return sat(at.X / w), 1 - sat(at.Y / svH)
	end
	local function nearKnob(point, i)
		local st = state(slot)
		local at = toStage(point) - toStage(sv.AbsolutePosition)
		local dx, dy = at.X - st.s[i] * w, at.Y - (1 - st.v[i]) * svH
		return dx * dx + dy * dy <= 11 * 11
	end
	Hit(scope, sv, {
		down = function(point)
			local st, col = state(slot), current()
			st.grab = st.stop
			if col.gradient then
				local n = nearKnob(point, 1) and 1 or (nearKnob(point, 2) and 2)
				if n then st.grab = n end
			end
			st.stop = st.grab
			dragging = true
			st.s[st.grab], st.v[st.grab] = fieldValues(point)
			commit(st.grab)
			redraw()
		end,
		drag = function(point)
			local st = state(slot)
			if st.grab then
				st.s[st.grab], st.v[st.grab] = fieldValues(point)
				commit(st.grab)
				redraw()
			end
		end,
		up = function() dragging = false; state(slot).grab = nil end,
		right = function(point)
			if not allowGradient then return end
			local st, col = state(slot), current()
			local ms, mv = fieldValues(point)
			if not col.gradient then
				startGradient(ms, mv)
			elseif nearKnob(point, 2) then
				col.gradient = false
				st.stop = 1
			elseif nearKnob(point, 1) then
				col.a, col.aa = col.b, col.ba
				st.h[1], st.s[1], st.v[1] = st.h[2], st.s[2], st.v[2]
				st.synced[1] = hexOf(col.a, col.aa)
				col.gradient = false
				st.stop = 1
			else
				st.s[2], st.v[2] = ms, mv
				commit(2)
				st.stop = 2
			end
			if onChange then onChange(col) end
			redraw()
		end,
	})
	local function barValue(point)
		return sat((toStage(point).X - toStage(hueBar.AbsolutePosition).X) / w)
	end
	Hit(scope, hueHit, {
		down = function(point)
			dragging = true
			local st = state(slot)
			st.h[st.stop] = clamp(barValue(point), 0, 0.9999)
			commit(st.stop)
			redraw()
		end,
		drag = function(point)
			local st = state(slot)
			st.h[st.stop] = clamp(barValue(point), 0, 0.9999)
			commit(st.stop)
			redraw()
		end,
		up = function() dragging = false end,
	})
	local function setAlpha(value)
		local st, col = state(slot), current()
		local c = stops(col, st.stop)
		setStop(col, st.stop, c, value)
		st.synced[st.stop] = hexOf(c, value)
		if onChange then onChange(col) end
		redraw()
	end
	Hit(scope, alphaHit, {
		down = function(point) dragging = true; setAlpha(barValue(point)) end,
		drag = function(point) setAlpha(barValue(point)) end,
		up = function() dragging = false end,
	})
	Hit(scope, fmtHit, {
		hover = function(b) fmtT:to(b and 1 or 0) end,
		click = function() mode = 1 - mode; redraw() end,
	})
	fmtT.cb = function() drawNow() end

	Hit(scope, input, {})
	Hit(scope, pctInput, {})
	connect(input:GetPropertyChangedSignal("Text"), function()
		if writingInputs or not input:IsFocused() then return end
		local st, col = state(slot), current()
		local c, a = stops(col, st.stop)
		if mode == 0 then
			local digits = string.gsub(input.Text, "[^%x]", "")
			if #digits == 6 or #digits == 8 then
				local v = tonumber(digits, 16)
				local alpha = a
				if #digits == 8 then alpha = (v % 256) / 255; v = v // 256 end
				setStop(col, st.stop, Color3.fromRGB((v // 65536) % 256, (v // 256) % 256, v % 256), alpha)
				if onChange then onChange(col) end
				redraw()
			end
		else
			local numbers = {}
			for n in string.gmatch(input.Text, "%d+") do table.insert(numbers, min(tonumber(n), 255)) end
			if #numbers == 3 then
				setStop(col, st.stop, Color3.fromRGB(numbers[1], numbers[2], numbers[3]), a)
				if onChange then onChange(col) end
				redraw()
			end
		end
	end, scope)
	connect(input.FocusLost, function() redraw() end, scope)
	connect(pctInput.FocusLost, function()
		local n = tonumber(string.match(pctInput.Text, "%d+"))
		if n then setAlpha(min(n, 100) / 100) else redraw() end
	end, scope)
	Wheel(scope, pctBox, function(z)
		local st, col = state(slot), current()
		local _, a = stops(col, st.stop)
		setAlpha(sat(a + z * 0.01))
	end)
	if allowGradient then
		local gradHit = Box(parent, btnX, ry, btnW, rowH)
		Hit(scope, gradHit, {
			hover = function(b) gradT:to(b and 1 or 0) end,
			click = function()
				local st, col = state(slot), current()
				if col.gradient then
					col.gradient = false
					st.stop = 1
					if onChange then onChange(col) end
				else
					startGradient(st.s[1], st.v[1] > 0.5 and st.v[1] - 0.4 or st.v[1] + 0.4)
				end
				redraw()
			end,
		})
		gradT.cb = function() drawNow() end
	end

	scope:paint(function()
		if view.init then drawNow() end
	end)
	card.onOpen = function()
		view.init = false
		redraw()
	end
	return ry + rowH, ry + rowH + 12
end

--[[ ---------------------------------------- Rows ------------------------------------------ ]]

local Flow = {}
Flow.__index = Flow

local function newFlow(o)
	return setmetatable({
		parent = o.parent, scope = o.scope, x = o.x or 0, y = o.y or 0, w = o.w, rw = o.rw or o.w, spacing = o.spacing or 0,
		separators = o.separators or false, card = o.card, level = o.level or 0, started = false, search = o.search, win = o.win,
		path = o.path or "", store = o.store, hostRight = o.hostRight, trail = 0, children = {},
	}, Flow)
end

local SearchFoldMap = {
	[0x401] = 0x435, [0x451] = 0x435, [0x130] = 105, [0x131] = 105,
	[0xC7] = 99, [0xE7] = 99, [0x11E] = 103, [0x11F] = 103,
	[0x15E] = 115, [0x15F] = 115, [0xD6] = 111, [0xF6] = 111,
	[0xDC] = 117, [0xFC] = 117,
}

local function normalizeSearch(text)
	local out = {}
	for _, code in utf8.codes(text) do
		if code >= 65 and code <= 90 then code += 32
		elseif code >= 0x410 and code <= 0x42F then code += 0x20
		else code = SearchFoldMap[code] or code end
		table.insert(out, utf8.char(code))
	end
	return table.concat(out)
end

local function triggerFlash(entry)
	if not entry then return end
	entry.flash = 0.4
	Run(function(dt)
		entry.flash = max(0, entry.flash - dt)
		if entry.paint then entry.paint() end
		if entry.flash <= 0 then
			entry.flash = 0
			if entry.paint then entry.paint() end
			return false
		end
		return true
	end, entry.scope)
end

local function attachDependsOn(object, rowData)
	function object:DependsOn(parentControl, expectedValueOrPredicate)
		local function evaluate()
			if not parentControl or not parentControl.Get then return true end
			local parentVal = parentControl:Get()
			if type(expectedValueOrPredicate) == "function" then
				return expectedValueOrPredicate(parentVal) == true
			elseif expectedValueOrPredicate ~= nil then
				return parentVal == expectedValueOrPredicate
			else
				return parentVal == true
			end
		end

		local function updateState(animate)
			local visible = evaluate()
			if rowData.targetVisible == visible then return end
			rowData.targetVisible = visible
			if animate and rowData.anim then
				rowData.anim:to(visible and 1 or 0)
			else
				if rowData.anim then rowData.anim:set(visible and 1 or 0) end
				rowData.heightScale = visible and 1 or 0
				if rowData.flow then rowData.flow:relayout() end
			end
		end

		if parentControl._changeListeners == nil then
			parentControl._changeListeners = {}
			local oldSet = parentControl.Set
			if oldSet then
				parentControl.Set = function(self, ...)
					local res = oldSet(self, ...)
					for _, listener in self._changeListeners do
						listener()
					end
					return res
				end
			end
		end
		table.insert(parentControl._changeListeners, function()
			updateState(true)
		end)

		updateState(false)
		return object
	end
end

function Flow:registerRow(rowFrame, height, separatorLine, rowScope, spacingAfter, layout)
	if not self.rows then self.rows = {} end
	local rowData = {
		frame = rowFrame,
		origY = rowFrame and rowFrame.Position.Y.Offset or self.y,
		height = height,
		heightScale = 1,
		targetVisible = true,
		flow = self,
		scope = rowScope or self.scope,
		separator = separatorLine,
		spacingAfter = spacingAfter,
		layout = layout,
	}
	rowData.anim = Anim(1, 14, function(v)
		rowData.heightScale = v
		if rowData.frame then
			rowData.frame.ClipsDescendants = true
			rowData.frame.Visible = v > 0.01
			setWH(rowData.frame, rowData.frame.Size.X.Offset, max(0, round(rowData.height * v)))
		end
		if rowData.separator then
			rowData.separator.Visible = v > 0.01
		end
		self:relayout()
	end, 0.01)
	table.insert(self.rows, rowData)
	return rowData
end

function Flow:resize(width)
	local oldWidth = self.rw
	if not oldWidth or oldWidth <= 0 then return end
	local factor = width / oldWidth
	self.x *= factor
	if self.w then self.w *= factor end
	self.rw = width
	if self.rows then
		for _, row in self.rows do
			if row.onResize then row.onResize(factor) end
		end
	end
	for _, child in self.children do child:resize(child.rw * factor) end
end

function Flow:relayout()
	if not self.rows or #self.rows == 0 then return end
	local currY = self.startY or self.rows[1].origY
	for _, r in self.rows do
		if r.separator then
			setXY(r.separator, self.x, currY)
			if r.heightScale > 0.01 and self.separators then
				currY += self.spacing
			end
		end
		if r.layout then
			r.layout(currY)
		elseif r.frame then
			setXY(r.frame, self.x, currY)
		end
		local effectiveH = round(r.height * r.heightScale)
		if r.frame then setWH(r.frame, r.frame.Size.X.Offset, effectiveH) end
		if r.heightScale > 0.01 then
			currY += effectiveH + (r.spacingAfter == nil and self.spacing or r.spacingAfter)
		end
	end
	self.y = currY
	self.scope:invalidateGrid(true)
	if self.box and self.box.tab then
		self.box.tab:layout()
	end
end

function Flow:rowBegin()
	local sepLine = nil
	if self.separators and self.started then
		sepLine = Box(self.parent, self.x, self.y, self.rw, 1, T.Separator)
		self.scope:paint(function()
			sepLine.BackgroundColor3, sepLine.BackgroundTransparency = T.Separator, 1 - self.scope.alpha
		end)
		self.y += self.spacing
	end
	self.lastSep = sepLine
	self.started = true
end

function Flow:advance(height)
	self.y += height + self.spacing
	self.trail = 0
end

-- Where the content really ends, without the gap left after the last section.
function Flow:bottom() return self.y - self.trail end

function Flow:note(label)
	if not self.search then return nil end
	local index = self.search.win.searchIndex
	local entry = {
		label = label, box = self.search.box, tabName = self.search.tabName, tab = self.search.tab,
		scope = self.scope, flash = 0, paint = nil,
		normalized = normalizeSearch(tr(label)), normalizedLanguage = Library.Language,
	}
	table.insert(index, entry)
	self.scope:onDestroy(function()
		local at = table.find(index, entry)
		if at then table.remove(index, at) end
	end)
	return entry
end

-- Every control with a flag is saved in configs. A control inside a card that has not been built
-- yet picks its saved value up from `pending` the moment it is created.
function Flow:flag(o, name, get, set)
	local store = self.store
	if not store or o.Flag == false then return nil end
	local base = o.Flag or (self.path .. "/" .. name)
	local count = (store.used[base] or 0) + 1
	store.used[base] = count
	local id = count > 1 and (base .. "#" .. count) or base
	store.controls[id] = { get = get, set = set }
	local waiting = store.pending[id]
	if waiting ~= nil then
		store.pending[id] = nil
		set(waiting)
	end
	return id
end

function Flow:changed()
	if self.store and self.store.onChange then self.store.onChange() end
end

local function flashColor(color, entry)
	if entry and entry.flash > 0 then return color:Lerp(Accent, min(1, entry.flash / 0.7)) end
	return color
end

local function splitIcon(name)
	local icon, text = string.match(name, "^%[(.-)%]%s*(.*)$")
	return icon, text or name
end

-- Same slot a colour swatch uses: just left of the toggle about to be drawn.
function Flow:swatchRect()
	return self.rw - 30 - 8 - 15, 5
end

function Flow:makeSwatch(row, x, y, value, o)
	local slots = o.slots or { { name = o.name, value = value } }
	assert(#slots > 0, "Color swatches require at least one color")
	for _, slot in slots do
		if typeof(slot.value) == "Color3" then slot.value = newColor(slot.value) end
		assert(type(slot.value) == "table" and typeof(slot.value.a) == "Color3", "Color swatches require Library.Color or Color3 values")
	end
	local currentSlot = slots[1]
	local current = currentSlot.value
	local size = 15
	local base, paintPreview = Preview(row, x, y, size, 4, self.scope)
	local ring = Box(row, x - 1, y - 1, size + 2, size + 2, nil, 5)
	local ringStroke = Stroke(ring)
	local hot = Anim(0, 15)
	local scope = self.scope
	local function paint()
		paintPreview(current)
		ringStroke.Color = White
		ringStroke.Transparency = 1 - 0.35 * hot.v * scope.alpha
	end
	hot.cb = paint
	scope:paint(paint)
	local level, win, path, store = self.level, self.win, self.path, self.store
	local cardObject
	local flow = self
	local function changed(col, silent)
		paint()
		if o.onChange and not silent then o.onChange(col) end
		flow:changed()
	end
	local function ensure()
		if cardObject then return cardObject end
		local allow = o.allowGradient ~= false
		cardObject = newCard({
			width = 274, padding = 16, name = "ColorPicker",
			build = function(card)
				local inner = newFlow({ parent = card.content, scope = card.scope, x = 16, y = 16, w = 242, rw = 240, card = card, level = card.level, win = win, path = path .. "/" .. (o.name or "Color"), store = store })
				local bottom, lineY = buildPicker(inner, slots, allow, changed, function(i)
					currentSlot = slots[i]
					current = currentSlot.value
					paint()
				end)
				local height = bottom
				inner.y = bottom + 20
				if o.extras then
					local line = Box(card.content, 16, lineY, 242, 1, T.PopupBorder)
					card.scope:paint(function()
						line.BackgroundColor3, line.BackgroundTransparency = T.PopupBorder, 1 - 0.55 * card.scope.alpha
					end)
					o.extras(inner)
					height = inner:bottom()
				end
				card:setHeight(height + 16)
			end,
			place = function(card)
				local at = toStage(base.AbsolutePosition)
				local view = viewport()
				local right = at.X + size + 12 + 274 <= view.X - 10
				local x0 = right and at.X + size + 12 or at.X - 12 - 274
				return keepOnScreen(card, x0, at.Y - 18)
			end,
		})
		return cardObject
	end
	Hit(scope, base, {
		hover = function(b) hot:to(b and 1 or 0) end,
		click = function()
			ensure():open(level)
			paint()
		end,
	})
	for _, slot in slots do
		local suffix = o.slots and ("." .. slot.name) or ".Color"
		self:flag(o, (o.name or "Color") .. suffix, function() return encodeColor(slot.value) end, function(data)
			decodeColor(slot.value, data)
			paint()
		end)
	end
	local object = {}
	local function copyColor(color)
		return newColor(color.a, color.aa, color.b, color.ba, color.gradient)
	end
	local function assignColor(target, data)
		if typeof(data) == "Color3" then
			target.a, target.b, target.gradient = data, data, false
			target.aa, target.ba = 1, 1
		elseif type(data) == "table" and typeof(data.a) == "Color3" then
			assert(type(data.aa) == "number" and type(data.ba) == "number" and data.aa >= 0 and data.aa <= 1 and data.ba >= 0 and data.ba <= 1, "Color alpha values must be between 0 and 1")
			target.a, target.b = data.a, typeof(data.b) == "Color3" and data.b or data.a
			target.aa, target.ba = data.aa, data.ba
			target.gradient = data.gradient == true
		elseif type(data) == "table" and type(data.c) == "string" then
			local first, firstAlpha = fromHex(data.c)
			local second, secondAlpha = fromHex(data.c2 or data.c)
			local alpha, alpha2 = tonumber(data.a) or firstAlpha, tonumber(data.a2) or secondAlpha
			assert(first and second and alpha >= 0 and alpha <= 1 and alpha2 >= 0 and alpha2 <= 1, "Encoded color data is invalid")
			target.a, target.b, target.aa, target.ba = first, second, alpha, alpha2
			target.gradient = data.g == true
		else
			error("Color:Set expects a Color3, Library.Color value, or encoded color table")
		end
	end
	function object:Get()
		if not o.slots then return copyColor(slots[1].value) end
		local values = {}
		for i, slot in slots do values[slot.name or i] = copyColor(slot.value) end
		return values
	end
	function object:Set(data, silent)
		if o.slots then
			assert(type(data) == "table", "Multi-color Set expects a table keyed by slot name or index")
			for i, slot in slots do
				local value = data[slot.name or i]
				if value ~= nil then assignColor(slot.value, value) end
			end
		else
			assignColor(slots[1].value, data)
		end
		current = currentSlot.value
		changed(current, silent)
	end
	return object
end

function Flow:dotsButton(row, x, y, o)
	local rect = Box(row, x - 3, y - 2, 21, 19, White, 6)
	local dots = {}
	for i = -1, 1 do dots[i] = circle(Box(rect, 9 + i * 4, 8, 3, 3, White, 1)) end
	local t = Anim(0, 15)
	local isUp, hovered = false, false
	local scope = self.scope
	local function paint()
		local a = scope.alpha
		rect.BackgroundColor3 = T.FrameInactive
		rect.BackgroundTransparency = 1 - 0.85 * t.v * a
		local col = T.Disabled:Lerp(T.Text, max(t.v, isUp and 1 or 0))
		for _, d in dots do d.BackgroundColor3, d.BackgroundTransparency = col, 1 - a end
	end
	t.cb = paint
	scope:paint(paint)
	local level, win, path, store = self.level, self.win, self.path, self.store
	local width = o.width or 240
	local card
	Hit(scope, rect, {
		hover = function(b)
			hovered = b
			t:to((b or isUp) and 1 or 0)
		end,
		click = function()
			if not card then
				card = newCard({
					width = width, name = "Options",
					build = function(c)
						local flow = newFlow({ parent = c.content, scope = c.scope, x = 10, y = 10, w = width - 20, rw = min(240, width - 20), card = c, level = c.level, win = win, path = path .. "/" .. (o.name or "Options") .. " options", store = store })
						o.build(flow)
						c:setHeight(flow:bottom() + 10)
					end,
					place = function(c)
						local at = toStage(rect.AbsolutePosition)
						return placeBeside(c, Vector2.new(at.X + 21, at.Y + 9))
					end,
				})
				card.onState = function(state)
					isUp = state
					t:to((state or hovered) and 1 or 0)
					paint()
				end
			end
			card:open(level)
		end,
	})
end

function Flow:Toggle(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local icon, text = splitIcon(o.Name)
	local value = o.Default == true
	local row = Box(self.parent, self.x, top, W, 25)
	local rowData = self:registerRow(row, 25, self.lastSep)
	local entry = self:note(text)
	local labelRight = W - 30 - 8
	if o.Color then
		local sx, sy = self:swatchRect()
		self:makeSwatch(row, sx, sy, o.Color, { name = text, extras = o.ColorExtras, onChange = o.ColorChanged, Flag = o.Flag and (o.Flag .. ".Color") or nil })
		labelRight = sx - 8
	elseif o.Options then
		local sx, sy = self:swatchRect()
		self:dotsButton(row, sx, sy, { build = o.Options, width = o.OptionsWidth, name = text })
		labelRight = sx - 11
	end
	local hover, on = Anim(0, 15), Anim(value and 1 or 0, 12)
	local paintSwitch = Switch(row, W - 30, 3, scope)
	local textX = 0
	local iconShape
	if icon then
		iconShape = Glyph(row, icon, 13.07)
		iconShape:center(7, 12.5)
		textX = 18
	end
	local label = ScrollText(row, textX, 0, labelRight - textX, 25, 12, nil, scope)
	local function paint()
		local t = max(on.v, hover.v)
		local color = flashColor(T.LabelOff:Lerp(T.LabelOn, t), entry)
		label:set(tr(text))
		label:paint(color, scope.alpha)
		if iconShape then iconShape:paint(color, scope.alpha) end
		paintSwitch(on.v)
	end
	hover.cb, on.cb = paint, paint
	if entry then entry.paint = paint end
	scope:paint(paint)
	local flow = self
	local object = { Default = o.Default == true }
	function object:Set(state, silent)
		value = state == true
		on:to(value and 1 or 0)
		if o.Callback and not silent then o.Callback(value) end
		flow:changed()
	end
	function object:Get() return value end
	Hit(scope, row, {
		hover = function(b) hover:to(b and 1 or 0); label:hover(b) end,
		click = function() object:Set(not value) end,
		right = function() object:Set(o.Default == true); triggerFlash(entry) end,
		tip = o.Tip ~= false and { text, o.Tip or "Click to enable or disable this option." } or nil,
	})
	self:flag(o, text, function() return value end, function(v) object:Set(v == true) end)
	attachDependsOn(object, rowData)
	self:advance(25)
	return object
end

-- Label, track and a value box you can type into. The same row in the menu and in every card.
function Flow:Slider(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local lo, hi = o.Min or 0, o.Max or 100
	local decimals = o.Decimals or 0
	local step = 10 ^ -decimals
	local format = o.Format or (decimals > 0 and ("%." .. decimals .. "f") or "%d")
	local value = clamp(o.Default or lo, lo, hi)
	local row = Box(self.parent, self.x, top, W, 25)
	local rowData = self:registerRow(row, 25, self.lastSep)
	local entry = self:note(o.Name)
	local numberW = 38
	local right = W - numberW - 12
	local left = floor(max(min(82, W * 0.45), right - 74))
	if right < left + 36 then left = floor(max(0, right - 36)) end
	local trackW = right - left
	local track = SoftBar(row, left, 10, trackW, T.FieldBg)
	local fill = SoftBar(row, left, 10, 0, Accent)
	local knob = circle(Box(row, left - 6, 6, 13, 13, White, 1))
	local label = ScrollText(row, 0, 0, left - 8, 25, 12, nil, scope)
	local box = Box(row, W - numberW, 2, numberW, 21, T.FieldBg, 6)
	local boxLine = Box(box, 1, 1, numberW - 2, 19, nil, 5)
	local stroke = Stroke(boxLine, T.Border)
	local input = New("TextBox", {
		Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, ClearTextOnFocus = false, FontFace = FontMedium, TextSize = 12, Size = UDim2.fromOffset(numberW, 16),
		Position = UDim2.fromOffset(0, capY(10.5, 12)), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	}, box)
	local hoverA, focusA, fillA = Anim(0, 15), Anim(0, 15), nil
	local editing = false
	local function shown() return string.format(format, value) end
	local function paint()
		local a = scope.alpha
		local x = fillA.v
		local color = flashColor(T.Disabled:Lerp(T.Text, max(x > 0.1 and 1 or 0, hoverA.v)), entry)
		label:set(tr(o.Name))
		label:paint(color, a)
		track.BackgroundColor3, track.BackgroundTransparency = T.FieldBg, 1 - A.FieldBg * a
		fill.BackgroundColor3, fill.BackgroundTransparency = Accent, 1 - a
		setWH(fill, round(x), 5)
		fill.Visible = x > 0.1
		setXY(knob, round(left + x - 6.5), 6)
		knob.BackgroundTransparency = 1 - a
		box.BackgroundColor3, box.BackgroundTransparency = T.FieldBg, 1 - A.FieldBg * a
		stroke.Color, stroke.Transparency = T.Border:Lerp(Accent, focusA.v), 1 - a
		local text = editing and input.Text or shown()
		local boxW = max(numberW, ceil(measure(text ~= "" and text or "0", 12)) + 14)
		if box.Size.X.Offset ~= boxW then
			setWH(box, boxW, 21)
			setXY(box, W - boxW, 2)
			setWH(boxLine, boxW - 2, 19)
			setWH(input, boxW, 16)
		end
		if not editing then input.Text = text end
		input.TextColor3, input.TextTransparency = T.Text, 1 - a
	end
	fillA = Anim(0, 15, paint, 0.05)
	hoverA.cb, focusA.cb = paint, paint
	if entry then entry.paint = paint end
	rowData.onResize = function(factor)
		W, numberW, left, trackW = W * factor, numberW * factor, left * factor, trackW * factor
		label:width(max(1, left - 8))
		fillA:set((value - lo) / max(hi - lo, 1e-6) * trackW)
	end

	local flow = self
	local object = { Default = o.Default or lo }
	function object:Set(new, silent)
		new = clamp(round(new / step) * step, lo, hi)
		if new == value then
			paint()
			return
		end
		value = new
		fillA:to((value - lo) / max(hi - lo, 1e-6) * trackW)
		if o.Callback and not silent then o.Callback(value) end
		flow:changed()
		paint()
	end
	function object:Get() return value end
	fillA:set((value - lo) / max(hi - lo, 1e-6) * trackW)
	scope:paint(paint)

	connect(input.Focused, function()
		editing = true
		input.Text = string.format(decimals > 0 and ("%." .. decimals .. "f") or "%d", value)
		input.CursorPosition = #input.Text + 1
		input.SelectionStart = 1
		focusA:to(1)
	end, scope)
	connect(input.FocusLost, function()
		editing = false
		local typed = tonumber((string.gsub(input.Text, "[^%d%.%-]", "")))
		if typed then object:Set(typed) end
		input.Text = shown()
		focusA:to(0)
		paint()
	end, scope)
	connect(input:GetPropertyChangedSignal("Text"), function()
		if editing then paint() end
	end, scope)

	local function fromPoint(p)
		local at = toStage(p).X - toStage(row.AbsolutePosition).X
		object:Set(lo + sat((at - left) / trackW) * (hi - lo))
	end
	Hit(scope, box, { hover = function(b) hoverA:to(b and 1 or 0) end })
	Hit(scope, Box(row, left - 7, 0, trackW + 14, 25), {
		down = fromPoint,
		drag = fromPoint,
		hover = function(b) hoverA:to(b and 1 or 0) end,
	})
	Hit(scope, row, {
		hover = function(b) hoverA:to(b and 1 or 0); label:hover(b) end,
		right = function()
			object:Set(o.Default or lo)
			triggerFlash(entry)
		end,
		tip = o.Tip and { o.Name, o.Tip } or nil,
	})
	Wheel(scope, row, function(z)
		if editing then return end
		local notches = z > 0 and ceil(z) or floor(z)
		object:Set(value + notches * max(step, floor((hi - lo) * 0.01 + 0.5)))
	end)
	self:flag(o, o.Name, function() return value end, function(v)
		if type(v) == "number" then object:Set(v) end
	end)
	attachDependsOn(object, rowData)
	self:advance(25)
	return object
end

local function chevronShape(parent, up)
	local d = up and -1 or 1
	return Shape(parent, strokeContours({ -3, -1.5 * d, 0, 1.5 * d, 3, -1.5 * d }, 1.15), 1, up and "CHEV_U" or "CHEV_D")
end

local function selectableRows(card, listW, options, isSelected, onPick, indent, topOffset)
	local rows = {}
	for i, option in options do
		local row = Box(card.content, 6, (topOffset or 6) + (i - 1) * 29, listW - 12, 25)
		local plate = Box(row, 0, 0, listW - 12, 25, T.FrameInactive, 6)
		local check = Glyph(row, "CHECK", 11.2)
		local t, hover = Anim(isSelected(i) and 1 or 0, 12), Anim(0, 15)
		local label = Label(row, "", 28, capY(12.5, 12), 12)
		local function paint()
			local a = card.scope.alpha
			plate.BackgroundColor3, plate.BackgroundTransparency = T.FrameInactive, 1 - hover.v * 0.6 * a
			check:paint(Accent, t.v * a)
			check:center(15 + (1 - t.v) * -4, 12.5)
			label.TextColor3 = T.Disabled:Lerp(T.Text, max(t.v, hover.v))
			label.TextTransparency = 1 - a
			setText(label, tr(option), 12)
			if indent then setXY(label, round(10 + 18 * indent.v), capY(12.5, 12)) end
		end
		t.cb, hover.cb = paint, paint
		card.scope:paint(paint)
		Hit(card.scope, row, {
			hover = function(b) hover:to(b and 1 or 0) end,
			click = function() onPick(i) end,
		})
		rows[i] = {
			frame = row,
			refresh = function() t:to(isSelected(i) and 1 or 0) end,
			paint = paint,
			layout = function(visible, y)
				row.Visible = visible
				if visible then setXY(row, 6, y) end
			end,
		}
	end
	return rows
end

local function dropdown(self, o, multi)
	self:rowBegin()
	local W, scope, level = self.rw, self.scope, self.level
	local options = o.Options
	assert(type(options) == "table" and #options > 0, "Combo Options must be a non-empty array")
	for _, option in options do assert(type(option) == "string" and option ~= "", "Combo options must be non-empty strings") end
	local searchable = o.Searchable == true
	local row = Box(self.parent, self.x, self.y, W, 25)
	local rowData = self:registerRow(row, 25, self.lastSep)
	local entry = self:note(o.Name)
	local comboW = min(130, max(70, W - 72))
	if o.Color then self:makeSwatch(row, W - comboW - 8 - 15, 5, o.Color, { name = o.Name }) end
	local bb = Box(row, W - comboW, 2, comboW, 21, T.FieldBg, 8)
	local line = Stroke(Box(bb, 1, 1, comboW - 2, 19, nil, 7), T.Border)
	local arrowDown = chevronShape(bb, false):at(comboW - 11, 10.5)
	local arrowUp = chevronShape(bb, true):at(comboW - 11, 10.5)
	local preview = ScrollText(bb, 10, 0, comboW - 34, 21, 12, nil, scope)
	local label = ScrollText(row, 0, 0, W - comboW - 8 - (o.Color and 23 or 0), 25, 12, nil, scope)
	local defaultIndex = type(o.Default) == "string" and table.find(options, o.Default) or (o.Default or 1)
	assert(multi or (type(defaultIndex) == "number" and defaultIndex % 1 == 0 and options[defaultIndex] ~= nil), "Combo Default must identify an option")
	local index, chosen = multi and 1 or defaultIndex, {}
	if multi then
		for i in options do chosen[i] = o.Default and o.Default[i] or false end
	end
	local hover, openA = Anim(0, 15), Anim(0, 15)
	local function isSelected(i)
		if multi then return chosen[i] end
		return i == index
	end
	local function anySelected()
		for i in options do
			if chosen[i] then return true end
		end
		return false
	end
	local function previewText()
		if not multi then return tr(options[index] or "") end
		local parts = {}
		for i, option in options do
			if chosen[i] then table.insert(parts, tr(option)) end
		end
		return #parts > 0 and table.concat(parts, ", ") or tr("Select")
	end
	local function paint()
		local a = scope.alpha
		local color = T.Disabled:Lerp(T.Text, max(openA.v, hover.v))
		bb.BackgroundColor3, bb.BackgroundTransparency = T.FieldBg, 1 - A.FieldBg * a
		line.Color, line.Transparency = T.Border, 1 - a
		arrowDown:paint(T.Text, a * (1 - openA.v))
		arrowUp:paint(T.Text, a * openA.v)
		preview:set(previewText())
		preview:paint(color, a)
		label:set(tr(o.Name))
		label:paint(flashColor(color, entry), a)
	end
	hover.cb, openA.cb = paint, paint
	if entry then entry.paint = paint end
	scope:paint(paint)

	local card, rows, indent, offset, searchInput
	local function centreOffset() return 7 + (index - 0.5) * 29 end
	local function refresh()
		if rows then
			for _, r in rows do r.refresh() end
		end
		if indent then indent:to(anySelected() and 1 or 0) end
		if offset and not multi then offset:to(centreOffset()) end
		paint()
	end
	local flow = self
	local object = { Default = o.Default }
	local function fire()
		if o.Callback then
			if multi then o.Callback(table.clone(chosen)) else o.Callback(options[index], index) end
		end
		flow:changed()
	end
	function object:Set(new, silent)
		if multi then
			assert(type(new) == "table", "Multi:Set expects a boolean array")
			for i in options do chosen[i] = new[i] == true end
		else
			local nextIndex = type(new) == "string" and table.find(options, new) or new
			assert(type(nextIndex) == "number" and nextIndex % 1 == 0 and options[nextIndex] ~= nil, "Combo:Set expects a valid option or index")
			index = nextIndex
		end
		refresh()
		if not silent then fire() end
	end
	function object:Get()
		if multi then return table.clone(chosen) end
		return options[index], index
	end
	local function ensure()
		if card then return card end
		local listW = comboW
		for _, option in options do listW = max(listW, ceil(measure(tr(option), 12)) + 46) end
		local searchHeight = searchable and 30 or 0
		local height = 12 + searchHeight + #options * 29 - 4
		card = newCard({
			width = listW, rounding = 10, padding = 6, name = multi and "MultiList" or "ComboList",
			build = function(c)
				if multi then indent = Anim(anySelected() and 1 or 0, 12) end
				if searchable then
					local field = Box(c.content, 6, 6, listW - 12, 24, T.FieldBg, 6)
					local fieldLine = Stroke(field, T.Border)
					searchInput = New("TextBox", {
						Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false, BackgroundTransparency = 1,
						FontFace = FontMedium, TextSize = 11, TextColor3 = T.Text, PlaceholderColor3 = T.Disabled,
						TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
						Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -14, 1, 0),
					}, field)
					c.scope:paint(function()
						field.BackgroundColor3, field.BackgroundTransparency = T.FieldBg, 1 - c.scope.alpha
						fieldLine.Color, fieldLine.Transparency = T.Border, 1 - c.scope.alpha
						searchInput.TextColor3, searchInput.TextTransparency = T.Text, 1 - c.scope.alpha
						searchInput.PlaceholderColor3 = T.Disabled
					end)
				end
				rows = selectableRows(c, listW, options, isSelected, function(i)
					if multi then
						chosen[i] = not chosen[i]
					else
						index = i
					end
					refresh()
					fire()
				end, indent, searchable and 36 or 6)
				local noResults
				if searchable then
					noResults = Label(c.content, tr("No matching options"), 12, 0, 10)
					noResults.TextColor3 = T.Disabled
					c.scope:paint(function()
						noResults.TextColor3, noResults.TextTransparency = T.Disabled, 1 - c.scope.alpha
					end)
				end
				if indent then
					indent.cb = function()
						for _, r in rows do r.paint() end
					end
				end
				if searchable then
					local function filterRows()
						local query = normalizeSearch(searchInput.Text)
						local count = 0
						for i, row in rows do
							local normalized = normalizeSearch(tr(options[i]))
							local visible = query == "" or string.find(normalized, query, 1, true) ~= nil
							row.layout(visible, 36 + count * 29)
							if visible then count += 1 end
						end
						noResults.Visible = count == 0
						setXY(noResults, 12, 36)
						c:setHeight(12 + 30 + max(1, count) * 29 - 4)
						c.scope:invalidateGrid(true)
					end
					connect(searchInput:GetPropertyChangedSignal("Text"), filterRows, c.scope)
					filterRows()
				end
				c:setHeight(height)
			end,
			place = function(c)
				local at, size = toStage(bb.AbsolutePosition), bb.AbsoluteSize / Scale
				local hostEdge = flow.hostRight and flow.hostRight() or at.X + size.X
				local x = max(at.X + size.X, hostEdge) + 8
				local middle = at.Y + size.Y * 0.5
				if multi then return keepOnScreen(c, x, middle - height * 0.5, 3) end
				c.middle = middle
				offset = offset or Anim(0, 12, function(v)
					c.base = Vector2.new(c.base.X, c.middle - v)
					c:apply()
				end)
				local target = centreOffset()
				offset.v, offset.t = target, target
				return keepOnScreen(c, x, middle - target, 3)
			end,
		})
		card.onState = function(state) openA:to(state and 1 or 0) end
		return card
	end
	Hit(scope, bb, {
		hover = function(b) hover:to(b and 1 or 0); preview:hover(b) end,
		click = function() ensure():open(level) end,
		tip = o.Tip and { o.Name, o.Tip } or nil,
	})
	Hit(scope, row, {
		right = function()
			if multi then
				local def = o.Default or {}
				for i in options do chosen[i] = def[i] == true end
			else
				index = o.Default or 1
			end
			refresh()
			fire()
			triggerFlash(entry)
		end,
	})
	if multi then
		self:flag(o, o.Name, function()
			return table.clone(chosen)
		end, function(v)
			if type(v) == "table" then
				for i in options do chosen[i] = v[i] == true end
				refresh()
			end
		end)
	else
		self:flag(o, o.Name, function() return options[index] end, function(v)
			local at = table.find(options, v)
			if at then
				index = at
				refresh()
			end
		end)
	end
	attachDependsOn(object, rowData)
	self:advance(25)
	return object
end

function Flow:Combo(o) return dropdown(self, o, false) end
function Flow:Multi(o) return dropdown(self, o, true) end

-- ============================================================================
-- Task 2.1: Flow:Keybind with Mode Context Menu
-- ============================================================================
local function keyToString(k)
	if k == nil then return "NONE" end
	if typeof(k) == "EnumItem" then
		if k.EnumType == Enum.KeyCode then
			return string.upper(k.Name)
		elseif k.EnumType == Enum.UserInputType then
			if k == Enum.UserInputType.MouseButton1 then return "MB1"
			elseif k == Enum.UserInputType.MouseButton2 then return "MB2"
			elseif k == Enum.UserInputType.MouseButton3 then return "MB3"
			else return string.upper(k.Name) end
		end
	elseif type(k) == "string" then
		return string.upper(k)
	end
	return "NONE"
end

local function parseKey(str)
	if not str or str == "" or string.upper(str) == "NONE" or string.upper(str) == "[NONE]" then return nil end
	local clean = string.gsub(string.gsub(str, "%[", ""), "%]", "")
	if clean == "MB1" then return Enum.UserInputType.MouseButton1
	elseif clean == "MB2" then return Enum.UserInputType.MouseButton2
	elseif clean == "MB3" then return Enum.UserInputType.MouseButton3
	end
	local kc = Enum.KeyCode[clean]
	if kc then return kc end
	local uit = Enum.UserInputType[clean]
	if uit then return uit end
	return nil
end

function Flow:Keybind(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local icon, text = splitIcon(o.Name)
	local key = o.Default
	local mode = o.Mode or "Hold"
	local toggleState = false
	local listening = false
	local showInList = o.ShowInList ~= false

	local row = Box(self.parent, self.x, top, W, 25)
	local rowData = self:registerRow(row, 25, self.lastSep)
	local entry = self:note(text)

	local textX = 0
	local iconShape
	if icon then
		iconShape = Glyph(row, icon, 13.07)
		iconShape:center(7, 12.5)
		textX = 18
	end

	local hover = Anim(0, 15)
	local badgeHover = Anim(0, 15)
	local badge = Box(row, W - 60, 3, 56, 19, T.FieldBg, 5)
	local badgeStroke = Stroke(badge, T.Border)
	local badgeLabel = Label(badge, keyToString(key), 0, 0, 10, FontMedium)
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.TextXAlignment = Enum.TextXAlignment.Center
	badgeLabel.TextYAlignment = Enum.TextYAlignment.Center

	local label = ScrollText(row, textX, 0, W - 70 - textX, 25, 12, nil, scope)

	local function updateBadgeLayout()
		local str = listening and "..." or keyToString(key)
		local bw = max(38, ceil(measure(str, 10, FontMedium)) + 16)
		setXY(badge, W - bw - 4, 3)
		setWH(badge, bw, 19)
		badgeLabel.Text = str
		label.w = W - bw - 14 - textX
		setWH(label.clip, label.w, 25)
	end

	local function paint()
		local t = hover.v
		local color = flashColor(T.LabelOff:Lerp(T.LabelOn, t), entry)
		label:set(tr(text))
		label:paint(color, scope.alpha)
		if iconShape then iconShape:paint(color, scope.alpha) end

		badge.BackgroundColor3 = T.FieldBg
		badge.BackgroundTransparency = 1 - scope.alpha
		if listening then
			badgeStroke.Color = Accent
			badgeStroke.Transparency = 1 - scope.alpha
			badgeLabel.TextColor3 = Accent
		else
			badgeStroke.Color = T.Border:Lerp(T.BorderHover or T.Title, badgeHover.v)
			badgeStroke.Transparency = 1 - scope.alpha
			badgeLabel.TextColor3 = T.Text
		end
		badgeLabel.TextTransparency = 1 - scope.alpha
	end

	hover.cb, badgeHover.cb = paint, paint
	if entry then entry.paint = paint end
	scope:paint(paint)

	local flow = self
	local object = {
		name = text,
		showInList = showInList,
		Default = o.Default,
		DefaultMode = o.Mode or "Hold",
	}

	function object:Get()
		return key, mode
	end

	function object:IsActive()
		if mode == "Always On" then return true
		elseif mode == "Off" then return false
		elseif mode == "Hold" then
			if typeof(key) == "EnumItem" then
				if key.EnumType == Enum.KeyCode then
					return UserInputService:IsKeyDown(key)
				elseif key.EnumType == Enum.UserInputType then
					return UserInputService:IsMouseButtonPressed(key)
				end
			end
			return false
		elseif mode == "Toggle" then
			return toggleState == true
		end
		return false
	end

	function object:Set(newKey, newMode, silent)
		if newKey ~= nil or newMode ~= nil then
			if newKey ~= nil then key = newKey end
			if newMode ~= nil then mode = newMode end
			updateBadgeLayout()
			paint()
			if not silent then
				if o.Callback then o.Callback(key, mode) end
				if o.ModeChanged then o.ModeChanged(mode) end
			end
			flow:changed()
			if refreshKeybindHUD then refreshKeybindHUD() end
		end
	end

	-- Key listening input connection
	local inputConn
	inputConn = connect(UserInputService.InputBegan, function(input, processed)
		if listening then
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
				key = nil
				listening = false
				updateBadgeLayout()
				paint()
				if o.Callback then o.Callback(key, mode) end
				flow:changed()
				if refreshKeybindHUD then refreshKeybindHUD() end
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				key = input.KeyCode
				listening = false
				updateBadgeLayout()
				paint()
				if o.Callback then o.Callback(key, mode) end
				flow:changed()
				if refreshKeybindHUD then refreshKeybindHUD() end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				key = input.UserInputType
				listening = false
				updateBadgeLayout()
				paint()
				if o.Callback then o.Callback(key, mode) end
				flow:changed()
				if refreshKeybindHUD then refreshKeybindHUD() end
			end
		elseif not processed and mode == "Toggle" and key ~= nil then
			local match = false
			if typeof(key) == "EnumItem" then
				if key.EnumType == Enum.KeyCode and input.KeyCode == key then
					match = true
				elseif key.EnumType == Enum.UserInputType and input.UserInputType == key then
					match = true
				end
			end
			if match then
				toggleState = not toggleState
				if o.Callback then o.Callback(key, mode, toggleState) end
				if refreshKeybindHUD then refreshKeybindHUD() end
			end
		end
	end, scope)

	-- Mode selection context popup card
	local modeCard = nil
	local function openModeMenu()
		if modeCard then modeCard:destroy() end
		modeCard = newCard({
			width = 110, padding = 6, name = "KeybindModes",
			place = function(mc)
				local at = toStage(badge.AbsolutePosition)
				local size = badge.AbsoluteSize / Scale
				return keepOnScreen(mc, at.X, at.Y + size.Y + 6)
			end,
			build = function(mc)
				local mf = newFlow({ parent = mc.content, scope = mc.scope, x = 6, y = 6, w = 98, rw = 98, card = mc, level = mc.level, win = flow.win })
				local modes = { "Always On", "Hold", "Toggle", "Off" }
				for _, m in modes do
					mf:Row(m == mode and "CHECK" or nil, m, function()
						mode = m
						if o.ModeChanged then o.ModeChanged(m) end
						flow:changed()
						if refreshKeybindHUD then refreshKeybindHUD() end
						mc:close()
					end)
				end
				mc:setHeight(mf:bottom() + 6)
			end,
		})
		modeCard:open(1)
	end

	Hit(scope, badge, {
		hover = function(b) badgeHover:to(b and 1 or 0) end,
		click = function()
			listening = not listening
			updateBadgeLayout()
			paint()
			wakeLoop()
		end,
		right = openModeMenu,
	})

	Hit(scope, row, {
		hover = function(b) hover:to(b and 1 or 0); label:hover(b) end,
		click = function()
			listening = not listening
			updateBadgeLayout()
			paint()
			wakeLoop()
		end,
		right = function()
			object:Set(o.Default, o.Mode or "Hold")
			triggerFlash(entry)
		end,
		tip = o.Tip ~= false and { text, o.Tip or "Click to bind key. Right-click pill for mode menu, or right-click row to reset." } or nil,
	})

	if self.win and self.win.keybinds then
		table.insert(self.win.keybinds, object)
	end

	self:flag(o, text, function()
		return { key = keyToString(key), mode = mode }
	end, function(v)
		if type(v) == "table" then
			object:Set(parseKey(v.key), v.mode, true)
		elseif type(v) == "string" then
			object:Set(parseKey(v), mode, true)
		end
	end)

	updateBadgeLayout()
	attachDependsOn(object, rowData)
	self:advance(25)
	return object
end

-- ============================================================================
-- Task 2.2: Flow:Textbox with Auto-Expanding Width & Password Masking
-- ============================================================================
function Flow:Textbox(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local icon, text = splitIcon(o.Name)
	local value = tostring(o.Default or "")
	local row = Box(self.parent, self.x, top, W, 25)
	local rowData = self:registerRow(row, 25, self.lastSep)
	local entry = self:note(text)

	local textX = 0
	local iconShape
	if icon then
		iconShape = Glyph(row, icon, 13.07)
		iconShape:center(7, 12.5)
		textX = 18
	end

	local baseW = min(110, round(W * 0.38))
	local expW = min(175, round(W * 0.55))
	local boxFrame = Box(row, W - baseW, 2, baseW, 21, T.FieldBg, 5)
	local stroke = Stroke(boxFrame, T.Border)

	local tb = New("TextBox", {
		Parent = boxFrame,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		FontFace = FontMedium,
		TextSize = 11,
		TextColor3 = T.Text,
		PlaceholderText = o.Placeholder or "...",
		PlaceholderColor3 = T.Disabled,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClipsDescendants = true,
	})

	local label = ScrollText(row, textX, 0, W - baseW - 8 - textX, 25, 12, nil, scope)
	local hover = Anim(0, 15)
	local focusAnim = Anim(0, 14, function(v)
		local curW = round(baseW + (expW - baseW) * v)
		setXY(boxFrame, W - curW, 2)
		setWH(boxFrame, curW, 21)
		label.w = W - curW - 8 - textX
		setWH(label.clip, label.w, 25)
		stroke.Color = T.Border:Lerp(Accent, v)
	end)

	local function updateDisplayText()
		if o.Password and not tb:IsFocused() then
			tb.Text = string.rep("•", #value)
		else
			tb.Text = value
		end
	end
	updateDisplayText()

	local function paint()
		local t = max(hover.v, focusAnim.v)
		local color = flashColor(T.LabelOff:Lerp(T.LabelOn, t), entry)
		label:set(tr(text))
		label:paint(color, scope.alpha)
		if iconShape then iconShape:paint(color, scope.alpha) end

		boxFrame.BackgroundColor3 = T.FieldBg
		boxFrame.BackgroundTransparency = 1 - scope.alpha
		stroke.Transparency = 1 - scope.alpha
		tb.TextColor3 = T.Text
		tb.TextTransparency = 1 - scope.alpha
		tb.PlaceholderColor3 = T.Disabled
	end

	hover.cb = paint
	if entry then entry.paint = paint end
	scope:paint(paint)

	local flow = self
	local object = { Default = tostring(o.Default or "") }

	function object:Get()
		return value
	end

	function object:Set(newVal, silent)
		value = tostring(newVal or "")
		updateDisplayText()
		if o.Callback and not silent then o.Callback(value) end
		flow:changed()
	end

	connect(tb.Focused, function()
		focusAnim:to(1)
		if o.Password then tb.Text = value end
		wakeLoop()
	end, scope)

	connect(tb.FocusLost, function(enterPressed)
		focusAnim:to(0)
		local t = tb.Text
		if o.Numeric then
			t = string.gsub(t, "[^0-9%.%-]", "")
		end
		if o.MaxLength and #t > o.MaxLength then
			t = string.sub(t, 1, o.MaxLength)
		end
		value = t
		updateDisplayText()
		if o.Callback then o.Callback(value) end
		flow:changed()
		wakeLoop()
	end, scope)

	if o.Live then
		connect(tb:GetPropertyChangedSignal("Text"), function()
			if not tb:IsFocused() then return end
			local t = tb.Text
			if o.Numeric then
				t = string.gsub(t, "[^0-9%.%-]", "")
			end
			if o.MaxLength and #t > o.MaxLength then
				t = string.sub(t, 1, o.MaxLength)
			end
			value = t
			if o.Callback then o.Callback(value) end
			flow:changed()
		end, scope)
	end

	Hit(scope, boxFrame, {})
	Hit(scope, row, {
		hover = function(b) hover:to(b and 1 or 0); label:hover(b) end,
		click = function() tb:CaptureFocus() end,
		right = function()
			object:Set(o.Default or "")
			triggerFlash(entry)
		end,
		tip = o.Tip ~= false and { text, o.Tip or "Click to enter text. Right-click to reset." } or nil,
	})

	self:flag(o, text, function() return value end, function(v) object:Set(v, true) end)
	attachDependsOn(object, rowData)
	self:advance(25)
	return object
end

local function numberField(flow, o, stepper)
	flow:rowBegin()
	local W, scope, top = flow.rw, flow.scope, flow.y
	local lo, hi = o.Min or -1e9, o.Max or 1e9
	local step = o.Step or 1
	assert(type(lo) == "number" and type(hi) == "number" and lo == lo and hi == hi and lo > -huge and hi < huge and lo <= hi, "NumberInput bounds must be finite and ordered")
	assert(type(step) == "number" and step == step and step > 0 and step < huge, "NumberInput Step must be finite and positive")
	local decimals = o.Decimals
	if decimals == nil then
		decimals = 0
		for places = 1, 8 do
			local scaled = step * 10 ^ places
			if abs(scaled - round(scaled)) < 1e-7 then decimals = places; break end
		end
	end
	assert(type(decimals) == "number" and decimals >= 0 and decimals <= 8 and decimals % 1 == 0, "Decimals must be an integer from 0 to 8")
	local precision = 10 ^ decimals
	local format = o.Format or (decimals > 0 and ("%." .. decimals .. "f") or "%d")
	local defaultValue = tonumber(o.Default)
	local default = clamp(defaultValue or (lo <= 0 and hi >= 0 and 0 or lo), lo, hi)
	local value
	local function normalize(newValue)
		assert(type(newValue) == "number" and newValue == newValue and abs(newValue) < huge, "NumberInput:Set expects a finite number")
		local rounded = lo + round((newValue - lo) / step) * step
		return clamp(round(rounded * precision) / precision, lo, hi)
	end
	value = normalize(default)
	local function shown() return string.format(format, value) end
	local controlWidth = stepper and 110 or 76
	local inputW = stepper and 54 or 76
	local row = Box(flow.parent, flow.x, top, W, 25)
	local rowData = flow:registerRow(row, 25, flow.lastSep)
	local entry = flow:note(o.Name)
	local label = ScrollText(row, 0, 0, max(1, W - controlWidth - 8), 25, 12, nil, scope)
	local inputX = W - controlWidth
	local box = Box(row, inputX, 2, inputW, 21, T.FieldBg, 6)
	local border = Stroke(Box(box, 1, 1, inputW - 2, 19, nil, 5), T.Border)
	local input = New("TextBox", {
		Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, ClearTextOnFocus = false, FontFace = FontMedium,
		TextSize = 12, Size = UDim2.fromOffset(inputW - 4, 16), Position = UDim2.fromOffset(2, capY(10.5, 12)),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	}, box)
	local focus = Anim(0, 15)
	local object = {}
	local function paint()
		local a = scope.alpha
		label:set(tr(o.Name))
		label:paint(flashColor(T.Disabled:Lerp(T.Text, focus.v), entry), a)
		box.BackgroundColor3, box.BackgroundTransparency = T.FieldBg, 1 - A.FieldBg * a
		border.Color, border.Transparency = T.Border:Lerp(Accent, focus.v), 1 - a
		input.TextColor3, input.TextTransparency = T.Text, 1 - a
		if not input:IsFocused() then input.Text = shown() end
	end
	local function setValue(newValue, silent)
		local nextValue = normalize(newValue)
		if nextValue == value then input.Text = shown(); return end
		value = nextValue
		input.Text = shown()
		paint()
		if o.Callback and not silent then o.Callback(value) end
		flow:changed()
	end
	function object:Set(newValue, silent) setValue(newValue, silent) end
	function object:Get() return value end
	focus.cb = paint
	if entry then entry.paint = paint end
	scope:paint(paint)
	connect(input.Focused, function() focus:to(1); input.Text = shown() end, scope)
	connect(input.FocusLost, function()
		focus:to(0)
		local parsed = tonumber(string.gsub(input.Text, "[^%d%.%-]", ""))
		if parsed then setValue(parsed) else input.Text = shown(); paint() end
	end, scope)
	local minus, plus
	if stepper then
		minus = Box(row, inputX + inputW + 4, 2, 20, 21, T.FrameInactive, 5)
		plus = Box(row, inputX + inputW + 27, 2, 20, 21, T.FrameInactive, 5)
		local minusLabel = Label(minus, "-", 0, capY(10.5, 12), 12, FontSemi)
		local plusLabel = Label(plus, "+", 0, capY(10.5, 12), 12, FontSemi)
		minusLabel.Size, plusLabel.Size = UDim2.fromScale(1, 1), UDim2.fromScale(1, 1)
		minusLabel.TextXAlignment, plusLabel.TextXAlignment = Enum.TextXAlignment.Center, Enum.TextXAlignment.Center
		scope:paint(function()
			local a = scope.alpha
			minus.BackgroundColor3, plus.BackgroundColor3 = T.FrameInactive, T.FrameInactive
			minus.BackgroundTransparency, plus.BackgroundTransparency = 1 - 0.8 * a, 1 - 0.8 * a
			minusLabel.TextColor3, plusLabel.TextColor3 = T.Text, T.Text
			minusLabel.TextTransparency, plusLabel.TextTransparency = 1 - a, 1 - a
		end)
		Hit(scope, minus, { click = function() setValue(value - step) end })
		Hit(scope, plus, { click = function() setValue(value + step) end })
	end
	Hit(scope, row, {
		hover = function(state) label:hover(state) end,
		right = function() setValue(default) end,
		tip = o.Tip and { o.Name, o.Tip } or nil,
	})
	connect(UserInputService.InputBegan, function(keyInput)
		if not input:IsFocused() then return end
		if keyInput.KeyCode == Enum.KeyCode.Up then setValue(value + step)
		elseif keyInput.KeyCode == Enum.KeyCode.Down then setValue(value - step) end
	end, scope)
	Wheel(scope, row, function(direction)
		if not input:IsFocused() then setValue(value + (direction > 0 and step or -step)) end
	end)
	rowData.onResize = function(factor)
		W, controlWidth, inputW = W * factor, controlWidth * factor, inputW * factor
		inputX = W - controlWidth
		label:width(max(1, W - controlWidth - 8))
		setXY(box, inputX, 2)
		setWH(box, inputW, 21)
		setWH(input, inputW - 4, 16)
		setWH(border.Parent, inputW - 2, 19)
		if stepper then
			setXY(minus, inputX + inputW + 4, 2)
			setXY(plus, inputX + inputW + 27, 2)
		end
	end
	flow:flag(o, o.Name, function() return value end, function(saved)
		if type(saved) == "number" then object:Set(saved, true) end
	end)
	attachDependsOn(object, rowData)
	flow:advance(25)
	return object
end

function Flow:NumberInput(o) return numberField(self, o, false) end
function Flow:Stepper(o) return numberField(self, o, true) end

local function selectorControl(flow, o, segmented)
	local options = o.Options
	assert(type(options) == "table" and #options > 0, "Selector Options must be a non-empty array")
	local indexByValue = {}
	for i, option in options do
		assert(type(option) == "string" and option ~= "", "Selector options must be non-empty strings")
		assert(indexByValue[option] == nil, "Selector options must be unique")
		indexByValue[option] = i
	end
	if o.Descriptions ~= nil then
		assert(type(o.Descriptions) == "table", "Descriptions must be an array")
		for _, description in o.Descriptions do assert(type(description) == "string", "Descriptions must contain strings") end
	end
	local index
	if type(o.Default) == "string" then index = indexByValue[o.Default] else index = o.Default or 1 end
	assert(type(index) == "number" and index % 1 == 0 and options[index] ~= nil, "Selector Default must identify an option")

	local horizontal = segmented or o.Layout == "Horizontal"
	assert(segmented or o.Layout == nil or o.Layout == "Horizontal" or o.Layout == "Vertical", "Radio Layout must be Horizontal or Vertical")
	local W, scope, top = flow.rw, flow.scope, flow.y
	local choiceH = segmented and 28 or 30
	local desc = o.Descriptions
	local hasDescriptions = not segmented and desc ~= nil
	local lineH = choiceH + (hasDescriptions and 14 or 0)
	local totalH = 18 + (horizontal and lineH or #options * lineH)
	local row = Box(flow.parent, flow.x, top, W, totalH)
	local rowData = flow:registerRow(row, totalH, flow.lastSep)
	local entry = flow:note(o.Name)
	local name = ScrollText(row, 0, 0, W, 16, 12, nil, scope)
	local choices = {}
	local entries = {}
	local object = {}
	local gap = horizontal and 4 or 0
	local function layout()
		local available = W - gap * (horizontal and #options - 1 or 0)
		local itemW = horizontal and available / #options or W
		for i, choice in choices do
			local y = horizontal and 18 or (18 + (i - 1) * lineH)
			local x = horizontal and (i - 1) * (itemW + gap) or 0
			setXY(choice.frame, round(x), round(y))
			setWH(choice.frame, max(1, round(itemW)), choiceH)
			setWH(choice.fill, max(1, round(itemW)), choiceH)
			if choice.radio then
				if horizontal then
					local indicatorSize, indicatorGap = 10, 5
					local textW = min(max(1, itemW - 8 - indicatorSize - indicatorGap), measure(tr(options[i]), 11))
					local groupW = indicatorSize + indicatorGap + textW
					local groupX = max(4, (itemW - groupW) * 0.5)
					setXY(choice.radio, round(groupX), round((choiceH - indicatorSize) * 0.5))
					setWH(choice.radio, indicatorSize, indicatorSize)
					choice.label.Position = UDim2.fromOffset(round(groupX + indicatorSize + indicatorGap), capY(choiceH * 0.5, 11))
					choice.label.Size = UDim2.new(0, max(1, round(textW)), 0, 16)
					choice.textWidth = max(1, round(textW))
				else
					setXY(choice.radio, 7, 9)
					setWH(choice.radio, 12, 12)
					choice.label.Position = UDim2.fromOffset(29, capY(choiceH * 0.5, 11))
					choice.label.Size = UDim2.new(1, -37, 0, 16)
				end
			end
			if choice.description then
				setWH(choice.description, max(1, round(itemW)), 14)
				setXY(choice.description, round(x), round(y + choiceH))
			end
		end
	end
	local function paint()
		local flashEntry = entry
		for _, optionEntry in entries do
			if optionEntry.flash > (flashEntry and flashEntry.flash or 0) then flashEntry = optionEntry end
		end
		name:set(tr(o.Name))
		name:paint(flashColor(T.Text, flashEntry), scope.alpha)
		for i, choice in choices do
			local selected = index == i
			local a = scope.alpha
			choice.fill.BackgroundColor3 = selected and T.FrameActive or T.FrameInactive
			choice.fill.BackgroundTransparency = 1 - (selected and 0.9 or 0.45 * choice.hover.v) * a
			choice.border.Color = selected and Accent or T.Border
			choice.border.Transparency = 1 - (selected and 0.8 or 0.5) * a
			if choice.radio then
				choice.radio.BackgroundColor3 = Accent
				choice.radio.BackgroundTransparency = selected and (1 - a) or 1
				choice.radioStroke.Color = selected and Accent or T.Disabled
				choice.radioStroke.Transparency = 1 - a
			end
			choice.label.TextColor3 = selected and T.Text or T.Disabled:Lerp(T.Text, choice.hover.v)
			choice.label.TextTransparency = 1 - a
			setText(choice.label, tr(options[i]), 11)
			if segmented then
				choice.label.Size = UDim2.new(1, -8, 0, 16)
				choice.label.Position = UDim2.fromOffset(4, capY(choiceH * 0.5, 11))
				choice.label.TextXAlignment = Enum.TextXAlignment.Center
			elseif horizontal then
				choice.label.Size = UDim2.new(0, choice.textWidth or 1, 0, 16)
			else
				choice.label.Position = UDim2.fromOffset(29, capY(choiceH * 0.5, 11))
				choice.label.Size = UDim2.new(1, -37, 0, 16)
			end
			if choice.description then
				setText(choice.description, tr(desc[i] or ""), 10)
				choice.description.TextColor3 = T.Disabled
				choice.description.TextTransparency = 1 - 0.85 * a
			end
		end
	end
	for i = 1, #options do
		local itemW = horizontal and (W - gap * (#options - 1)) / #options or W
		local y = horizontal and 18 or (18 + (i - 1) * lineH)
		local frame = Box(row, 0, y, itemW, choiceH)
		local fill = Box(frame, 0, 0, itemW, choiceH, T.FrameInactive, segmented and 6 or 4)
		local border = Stroke(Box(frame, 1, 1, itemW - 2, choiceH - 2, nil, segmented and 5 or 3), T.Border)
		local radio, radioStroke
		local labelX = 0
		if not segmented then
			radio = circle(Box(frame, 7, 9, 12, 12, T.FieldBg, 6))
			radioStroke = Stroke(radio, T.Disabled, 1)
			labelX = 29
		end
		local label = Label(frame, "", labelX, capY(choiceH * 0.5, 11), 11)
		label.Size = UDim2.new(1, -labelX - 4, 0, 16)
		label.TextXAlignment = segmented and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local description
		if hasDescriptions then
			description = Label(row, "", 0, y + choiceH, 10)
			description.Size = UDim2.new(1, 0, 0, 14)
			description.TextTruncate = Enum.TextTruncate.AtEnd
		end
		local choice = { frame = frame, fill = fill, border = border, radio = radio, radioStroke = radioStroke, label = label, description = description, hover = Anim(0, 15) }
		choice.hover.cb = paint
		choices[i] = choice
		Hit(scope, frame, {
			hover = function(state) choice.hover:to(state and 1 or 0) end,
			click = function() object:Set(i) end,
		})
		local optionEntry = flow:note(options[i])
		if optionEntry then
			optionEntry.paint = paint
			table.insert(entries, optionEntry)
		end
	end
	if entry then entry.paint = paint end
	function object:Get() return options[index], index end
	function object:Set(newIndex, silent)
		if type(newIndex) == "string" then newIndex = indexByValue[newIndex] end
		assert(type(newIndex) == "number" and newIndex % 1 == 0 and options[newIndex] ~= nil, "Selector:Set expects a valid option index")
		if index == newIndex then return end
		index = newIndex
		paint()
		if o.Callback and not silent then o.Callback(options[index], index) end
		flow:changed()
	end
	scope:paint(paint)
	rowData.onResize = function(factor)
		W *= factor
		name:width(W)
		layout()
	end
	layout()
	flow:flag(o, o.Name, function() return options[index] end, function(saved)
		local restored = type(saved) == "number" and saved or indexByValue[saved]
		if restored then object:Set(restored, true) end
	end)
	attachDependsOn(object, rowData)
	flow:advance(totalH)
	return object
end

function Flow:Segmented(o) return selectorControl(self, o, true) end
function Flow:Radio(o) return selectorControl(self, o, false) end

-- ============================================================================
-- Task 2.3: Flow:Button & Flow:ButtonRow with 2.5s Confirm Timer
-- ============================================================================
function Flow:Button(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local icon, text = splitIcon(o.Name or o.Text or "")
	if o.Icon then icon = o.Icon end

	local row = Box(self.parent, self.x, top, W, 26, T.Button, 6)
	local rowData = self:registerRow(row, 26, self.lastSep)
	local stroke = Stroke(row, T.Border)

	local iconShape
	local label = Label(row, tr(text), 0, 0, 11, FontSemi)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	if icon then
		iconShape = Glyph(row, icon, 12)
		iconShape:center(14, 13)
	end

	local hover = Anim(0, 15)
	local press = Anim(0, 20)
	local confirming = false
	local confirmUntil = 0
	local cancelConfirmJob
	local warnColor = Color3.fromRGB(240, 140, 50)

	local function paint()
		local a = scope.alpha
		local btnBg = confirming and warnColor:Lerp(T.ButtonActive, 0.4) or T.Button:Lerp(T.ButtonHovered, hover.v):Lerp(T.ButtonActive, press.v)
		row.BackgroundColor3 = btnBg
		row.BackgroundTransparency = 1 - a

		stroke.Color = confirming and warnColor or T.Border:Lerp(T.Title, hover.v)
		stroke.Transparency = 1 - a

		local txtColor = confirming and White or T.Text
		label.TextColor3 = txtColor
		label.TextTransparency = 1 - a
		label.Text = confirming and tr("Click again to confirm") or tr(text)

		if iconShape then
			iconShape:paint(txtColor, a)
		end
	end

	hover.cb, press.cb = paint, paint
	scope:paint(paint)

	local object = {}
	Hit(scope, row, {
		hover = function(b) hover:to(b and 1 or 0) end,
		down = function() press:to(1) end,
		up = function() press:to(0) end,
		click = function()
			if o.Confirm then
				if confirming then
					confirming = false
					if cancelConfirmJob then cancelConfirmJob(); cancelConfirmJob = nil end
					paint()
					if o.Callback then o.Callback() end
				else
					confirming = true
					confirmUntil = tick() + 2.5
					paint()
					cancelConfirmJob = Run(function()
						if not confirming then return false end
						if tick() >= confirmUntil then
							confirming = false
							cancelConfirmJob = nil
							paint()
							return false
						end
						return true
					end, scope)
				end
			else
				if o.Callback then o.Callback() end
			end
		end,
		tip = o.Tip ~= false and o.Tip and { text, o.Tip } or nil,
	})

	attachDependsOn(object, rowData)
	self:advance(26)
	return object
end

function Flow:ButtonRow(leftOpts, rightOpts)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local row = Box(self.parent, self.x, top, W, 26)
	local rowData = self:registerRow(row, 26, self.lastSep)
	local btnW = round((W - 6) * 0.5)

	local function makeHalfBtn(opts, xPos)
		local icon, text = splitIcon(opts.Name or opts.Text or "")
		if opts.Icon then icon = opts.Icon end

		local btn = Box(row, xPos, 0, btnW, 26, T.Button, 6)
		local stroke = Stroke(btn, T.Border)
		local label = Label(btn, tr(text), 0, 0, 11, FontSemi)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center

		local iconShape
		if icon then
			iconShape = Glyph(btn, icon, 12)
			iconShape:center(12, 13)
		end

		local hover = Anim(0, 15)
		local press = Anim(0, 20)
		local confirming = false
		local confirmUntil = 0
		local cancelConfirmJob
		local warnColor = Color3.fromRGB(240, 140, 50)

		local function paint()
			local a = scope.alpha
			local btnBg = confirming and warnColor:Lerp(T.ButtonActive, 0.4) or T.Button:Lerp(T.ButtonHovered, hover.v):Lerp(T.ButtonActive, press.v)
			btn.BackgroundColor3 = btnBg
			btn.BackgroundTransparency = 1 - a

			stroke.Color = confirming and warnColor or T.Border:Lerp(T.Title, hover.v)
			stroke.Transparency = 1 - a

			local txtColor = confirming and White or T.Text
			label.TextColor3 = txtColor
			label.TextTransparency = 1 - a
			label.Text = confirming and tr("Confirm?") or tr(text)

			if iconShape then
				iconShape:paint(txtColor, a)
			end
		end

		hover.cb, press.cb = paint, paint
		scope:paint(paint)

		Hit(scope, btn, {
			hover = function(b) hover:to(b and 1 or 0) end,
			down = function() press:to(1) end,
			up = function() press:to(0) end,
			click = function()
				if opts.Confirm then
					if confirming then
						confirming = false
						if cancelConfirmJob then cancelConfirmJob(); cancelConfirmJob = nil end
						paint()
						if opts.Callback then opts.Callback() end
					else
						confirming = true
						confirmUntil = tick() + 2.5
						paint()
						cancelConfirmJob = Run(function()
							if not confirming then return false end
							if tick() >= confirmUntil then
								confirming = false
								cancelConfirmJob = nil
								paint()
								return false
							end
							return true
						end, scope)
					end
				else
					if opts.Callback then opts.Callback() end
				end
			end,
			tip = opts.Tip ~= false and opts.Tip and { text, opts.Tip } or nil,
		})
	end

	makeHalfBtn(leftOpts, 0)
	makeHalfBtn(rightOpts, btnW + 6)

	local object = {}
	attachDependsOn(object, rowData)
	self:advance(26)
	return object
end

-- ============================================================================
-- Task 2.4: Flow:RangeSlider Dual-Knob Range Slider
-- ============================================================================
function Flow:RangeSlider(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local icon, text = splitIcon(o.Name)
	local lo, hi = o.Min or 0, o.Max or 100
	local decimals = o.Decimals or 0
	local formatStr = o.Format

	local defLo = o.Default and o.Default[1] or lo
	local defHi = o.Default and o.Default[2] or hi
	local minVal = clamp(defLo, lo, hi)
	local maxVal = clamp(defHi, minVal, hi)

	local row = Box(self.parent, self.x, top, W, 36)
	local rowData = self:registerRow(row, 36, self.lastSep)
	local entry = self:note(text)

	local textX = 0
	local iconShape
	if icon then
		iconShape = Glyph(row, icon, 13.07)
		iconShape:center(7, 8)
		textX = 18
	end

	local label = ScrollText(row, textX, 0, W - 90 - textX, 18, 12, nil, scope)
	local valuePill = Label(row, "", W - 80, capY(8, 10), 10, FontMedium)
	valuePill.Size = UDim2.fromOffset(80, 16)
	valuePill.TextXAlignment = Enum.TextXAlignment.Right

	local track = Box(row, 0, 22, W, 4, T.FieldBg, 2)
	local fill = Box(track, 0, 0, W, 4, Accent, 2)
	local minKnob = Box(row, 0, 19, 10, 10, White, 5)
	local maxKnob = Box(row, 0, 19, 10, 10, White, 5)
	local minStroke = Stroke(minKnob, Accent, 1)
	local maxStroke = Stroke(maxKnob, Accent, 1)

	local hover = Anim(0, 15)
	local activeKnob = nil

	local function formatValue(v)
		if formatStr then
			return string.format(formatStr, v)
		end
		if decimals > 0 then
			return string.format("%." .. decimals .. "f", v)
		end
		return tostring(round(v))
	end

	local function updateRangeLayout()
		local span = max(hi - lo, 1e-4)
		local minRatio = sat((minVal - lo) / span)
		local maxRatio = sat((maxVal - lo) / span)

		local minX = round(minRatio * (W - 10))
		local maxX = round(maxRatio * (W - 10))

		setXY(minKnob, minX, 19)
		setXY(maxKnob, maxX, 19)

		setXY(fill, minX + 5, 0)
		setWH(fill, max(0, maxX - minX), 4)

		valuePill.Text = formatValue(minVal) .. " - " .. formatValue(maxVal)
	end
	rowData.onResize = function(factor)
		W *= factor
		label:width(max(1, W - 90 - textX))
		updateRangeLayout()
	end

	local function paint()
		local t = hover.v
		local color = flashColor(T.LabelOff:Lerp(T.LabelOn, t), entry)
		label:set(tr(text))
		label:paint(color, scope.alpha)
		if iconShape then iconShape:paint(color, scope.alpha) end

		track.BackgroundColor3 = T.FieldBg
		track.BackgroundTransparency = 1 - scope.alpha
		fill.BackgroundColor3 = Accent
		fill.BackgroundTransparency = 1 - scope.alpha

		valuePill.TextColor3 = flashColor(T.Text, entry)
		valuePill.TextTransparency = 1 - scope.alpha

		minKnob.BackgroundTransparency = 1 - scope.alpha
		maxKnob.BackgroundTransparency = 1 - scope.alpha
		minStroke.Transparency = 1 - scope.alpha
		maxStroke.Transparency = 1 - scope.alpha
	end

	hover.cb = paint
	if entry then entry.paint = paint end
	scope:paint(paint)

	local flow = self
	local object = { Default = { defLo, defHi } }

	function object:Get()
		return { minVal, maxVal }
	end

	function object:Set(tbl, silent)
		if type(tbl) == "table" then
			local nLo = clamp(tonumber(tbl[1]) or lo, lo, hi)
			local nHi = clamp(tonumber(tbl[2]) or hi, nLo, hi)
			minVal, maxVal = nLo, nHi
			updateRangeLayout()
			paint()
			if o.Callback and not silent then o.Callback({ minVal, maxVal }) end
			flow:changed()
		end
	end

	local function handleInput(p)
		local mouseX = toStage(p).X - toStage(row.AbsolutePosition).X
		local ratio = sat((mouseX - 5) / (W - 10))
		local val = lo + ratio * (hi - lo)
		if decimals == 0 then val = round(val) end

		if activeKnob == "min" then
			minVal = clamp(val, lo, maxVal)
		elseif activeKnob == "max" then
			maxVal = clamp(val, minVal, hi)
		end
		updateRangeLayout()
		paint()
	end

	Hit(scope, row, {
		hover = function(b) hover:to(b and 1 or 0); label:hover(b) end,
		down = function(p)
			local mouseX = toStage(p).X - toStage(row.AbsolutePosition).X
			local span = max(hi - lo, 1e-4)
			local minX = ((minVal - lo) / span) * (W - 10) + 5
			local maxX = ((maxVal - lo) / span) * (W - 10) + 5

			if abs(mouseX - minX) <= abs(mouseX - maxX) then
				activeKnob = "min"
			else
				activeKnob = "max"
			end
			handleInput(p)
		end,
		drag = function(p)
			if activeKnob then handleInput(p) end
		end,
		up = function()
			if activeKnob then
				activeKnob = nil
				if o.Callback then o.Callback({ minVal, maxVal }) end
				flow:changed()
			end
		end,
		right = function()
			object:Set(o.Default or { lo, hi })
			triggerFlash(entry)
		end,
		tip = o.Tip ~= false and { text, o.Tip or "Drag knobs to adjust min and max range. Right-click to reset." } or nil,
	})

	self:flag(o, text, function()
		return { minVal, maxVal }
	end, function(v)
		if type(v) == "table" then
			object:Set(v, true)
		end
	end)

	updateRangeLayout()
	attachDependsOn(object, rowData)
	self:advance(36)
	return object
end

-- ============================================================================
-- Task 2.6: Flow:CurveEditor Spline / Curve Editor
-- ============================================================================
function Flow:CurveEditor(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local icon, text = splitIcon(o.Name)
	local points = {}
	local minPointGap = 0.04
	if o.Points and #o.Points > 0 then
		for _, pt in o.Points do
			table.insert(points, Vector2.new(clamp(pt.X, 0, 1), clamp(pt.Y, 0, 1)))
		end
	else
		points = { Vector2.new(0, 0), Vector2.new(0.4, 0.8), Vector2.new(1, 1) }
	end
	local function normalizePoints()
		table.sort(points, function(a, b) return a.X < b.X end)
		if #points == 1 then
			points[1] = Vector2.new(0, points[1].Y)
		elseif #points > 1 then
			local gap = min(minPointGap, 1 / (#points - 1))
			points[1] = Vector2.new(0, points[1].Y)
			for i = 2, #points - 1 do
				local maxX = 1 - gap * (#points - i)
				points[i] = Vector2.new(clamp(points[i].X, points[i - 1].X + gap, maxX), points[i].Y)
			end
			points[#points] = Vector2.new(1, points[#points].Y)
		end
	end
	normalizePoints()

	local row = Box(self.parent, self.x, top, W, 126)
	local rowData = self:registerRow(row, 126, self.lastSep)
	local entry = self:note(text)

	local textX = 0
	local iconShape
	if icon then
		iconShape = Glyph(row, icon, 13.07)
		iconShape:center(7, 8)
		textX = 18
	end

	local label = Label(row, tr(text), textX, capY(9, 11), 11, FontSemi)
	local hint = Label(row, tr("Spline"), W, capY(9, 9), 9, FontRegular)
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.TextXAlignment = Enum.TextXAlignment.Right

	local canvas = Box(row, 0, 20, W, 100, T.FieldBg, 6)
	local canvasStroke = Stroke(canvas, T.Border)

	-- Grid lines
	for i = 1, 3 do
		local yLine = Box(canvas, 0, round(100 * i / 4), W, 1, T.Separator)
		local xLine = Box(canvas, round(W * i / 4), 0, 1, 100, T.Separator)
		scope:paint(function()
			yLine.BackgroundColor3 = T.Separator
			yLine.BackgroundTransparency = 1 - 0.4 * scope.alpha
			xLine.BackgroundColor3 = T.Separator
			xLine.BackgroundTransparency = 1 - 0.4 * scope.alpha
		end)
	end

	local curveSegments = 64
	local segs = {}
	for i = 1, curveSegments do
		local seg = Box(canvas, 0, 0, 10, 2, Accent)
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		table.insert(segs, seg)
	end

	-- Knob frames
	local knobFrames = {}
	local function ensureKnobs()
		for i = #knobFrames + 1, #points do
			local kf = Box(canvas, 0, 0, 10, 10, White, 5)
			kf.AnchorPoint = Vector2.new(0.5, 0.5)
			local ks = Stroke(kf, Accent, 1.5)
			scope:paint(function()
				kf.BackgroundTransparency = 1 - scope.alpha
				ks.Transparency = 1 - scope.alpha
				ks.Color = Accent
			end)
			table.insert(knobFrames, kf)
		end
		for i = #points + 1, #knobFrames do
			knobFrames[i].Visible = false
		end
	end

	local tangents = {}
	local function rebuildTangents()
		table.clear(tangents)
		local count = #points
		if count < 2 then return end

		local spans, slopes = {}, {}
		for i = 1, count - 1 do
			spans[i] = max(points[i + 1].X - points[i].X, 1e-4)
			slopes[i] = (points[i + 1].Y - points[i].Y) / spans[i]
		end
		tangents[1], tangents[count] = slopes[1], slopes[count - 1]
		for i = 2, count - 1 do
			local before, after = slopes[i - 1], slopes[i]
			if before * after <= 0 then
				tangents[i] = 0
			else
				local beforeSpan, afterSpan = spans[i - 1], spans[i]
				local w1, w2 = 2 * afterSpan + beforeSpan, afterSpan + 2 * beforeSpan
				tangents[i] = (w1 + w2) / (w1 / before + w2 / after)
			end
		end

		for i = 1, count - 1 do
			local slope = slopes[i]
			if abs(slope) < 1e-8 then
				tangents[i], tangents[i + 1] = 0, 0
			else
				local a, b = tangents[i] / slope, tangents[i + 1] / slope
				local magnitude = a * a + b * b
				if magnitude > 9 then
					local scale = 3 / math.sqrt(magnitude)
					tangents[i], tangents[i + 1] = scale * a * slope, scale * b * slope
				end
			end
		end
	end

	local function evaluate(t)
		t = clamp(t, 0, 1)
		if #points == 0 then return 0 end
		if #points == 1 then return points[1].Y end
		if t <= points[1].X then return points[1].Y end
		if t >= points[#points].X then return points[#points].Y end

		local idx = 1
		for i = 1, #points - 1 do
			if t >= points[i].X and t <= points[i + 1].X then
				idx = i
				break
			end
		end

		local p1 = points[idx]
		local p2 = points[idx + 1]
		local span = max(p2.X - p1.X, 1e-4)
		local localT = (t - p1.X) / span
		local t2 = localT * localT
		local t3 = t2 * localT
		local h00, h10 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + localT
		local h01, h11 = -2 * t3 + 3 * t2, t3 - t2
		local y = h00 * p1.Y + h10 * span * tangents[idx] + h01 * p2.Y + h11 * span * tangents[idx + 1]

		return clamp(y, 0, 1)
	end
	rebuildTangents()

	local function redraw()
		ensureKnobs()
		local pad = 6
		local cw = W - pad * 2
		local ch = 100 - pad * 2

		for i, pt in points do
			local kf = knobFrames[i]
			kf.Visible = true
			kf.Position = UDim2.fromOffset(round(pad + pt.X * cw), round(pad + (1 - pt.Y) * ch))
		end

		local prevX = pad
		local prevY = pad + (1 - evaluate(0)) * ch
		for i = 1, curveSegments do
			local t = i / curveSegments
			local curX = pad + t * cw
			local curY = pad + (1 - evaluate(t)) * ch

			local seg = segs[i]
			local dx = curX - prevX
			local dy = curY - prevY
			local len = math.sqrt(dx * dx + dy * dy)

			seg.Size = UDim2.fromOffset(round(len), 2)
			seg.Position = UDim2.fromOffset(round((prevX + curX) * 0.5), round((prevY + curY) * 0.5))
			seg.Rotation = math.deg(math.atan2(dy, dx))
			seg.BackgroundColor3 = Accent
			seg.BackgroundTransparency = 1 - scope.alpha

			prevX, prevY = curX, curY
		end
	end
	rowData.onResize = function(factor)
		W *= factor
		setWH(canvas, W, 100)
		setXY(hint, W, capY(9, 9))
		redraw()
	end

	local hover = Anim(0, 15)
	local function paint()
		local t = hover.v
		local color = flashColor(T.LabelOff:Lerp(T.LabelOn, t), entry)
		label.TextColor3 = color
		label.TextTransparency = 1 - scope.alpha
		hint.TextColor3 = T.Disabled
		hint.TextTransparency = 1 - scope.alpha

		canvas.BackgroundColor3 = T.FieldBg
		canvas.BackgroundTransparency = 1 - scope.alpha
		canvasStroke.Color = T.Border
		canvasStroke.Transparency = 1 - scope.alpha
		redraw()
	end

	hover.cb = paint
	if entry then entry.paint = paint end
	scope:paint(paint)

	local flow = self
	local defaultPoints = {}
	for _, p in points do table.insert(defaultPoints, Vector2.new(p.X, p.Y)) end

	local object = {}
	function object:Evaluate(t)
		return evaluate(t)
	end

	function object:Get()
		local copy = {}
		for _, p in points do
			table.insert(copy, Vector2.new(p.X, p.Y))
		end
		return copy
	end

	function object:Set(newPts, silent)
		if type(newPts) == "table" and #newPts > 0 then
			points = {}
			for _, pt in newPts do
				if typeof(pt) == "Vector2" then
					table.insert(points, Vector2.new(clamp(pt.X, 0, 1), clamp(pt.Y, 0, 1)))
				elseif type(pt) == "table" and pt.X and pt.Y then
					table.insert(points, Vector2.new(clamp(pt.X, 0, 1), clamp(pt.Y, 0, 1)))
				end
			end
			normalizePoints()
			rebuildTangents()
			redraw()
			paint()
			if o.Callback and not silent then o.Callback(object:Get()) end
			flow:changed()
		end
	end

	local dragIdx = nil
	local function pointAt(p)
		local pad = 6
		local cw, ch = W - pad * 2, 100 - pad * 2
		local pointer, origin = toStage(p), toStage(canvas.AbsolutePosition)
		local mx, my = pointer.X - origin.X, pointer.Y - origin.Y
		return clamp((mx - pad) / cw, 0, 1), clamp(1 - (my - pad) / ch, 0, 1), mx, my
	end

	Hit(scope, canvas, {
		hover = function(b) hover:to(b and 1 or 0) end,
		down = function(p)
			local pad = 6
			local cw = W - pad * 2
			local ch = 100 - pad * 2
			local nx, ny, mx, my = pointAt(p)

			local closest, closestDist = nil, 20
			for i, pt in points do
				local kx = pad + pt.X * cw
				local ky = pad + (1 - pt.Y) * ch
				local d = math.sqrt((mx - kx)^2 + (my - ky)^2)
				if d < closestDist then
					closest = i
					closestDist = d
				end
			end
			dragIdx = closest
			if not dragIdx and #points < 12 then
				local insertAt = #points + 1
				for i, pt in points do
					if nx < pt.X then
						insertAt = i
						break
					end
				end
				local before, after = points[insertAt - 1], points[insertAt]
				if (not before or nx - before.X >= minPointGap) and (not after or after.X - nx >= minPointGap) then
					table.insert(points, insertAt, Vector2.new(nx, ny))
					dragIdx = insertAt
					rebuildTangents()
					redraw()
				end
			end
		end,
		drag = function(p)
			if dragIdx then
				local nx, ny = pointAt(p)
				if dragIdx == 1 then
					nx = 0
				elseif dragIdx == #points then
					nx = 1
				else
					nx = clamp(nx, points[dragIdx - 1].X + minPointGap, points[dragIdx + 1].X - minPointGap)
				end
				points[dragIdx] = Vector2.new(nx, ny)
				rebuildTangents()
				redraw()
			end
		end,
		up = function()
			if dragIdx then
				dragIdx = nil
				if o.Callback then o.Callback(object:Get()) end
				flow:changed()
			end
		end,
		right = function(p)
			local _, _, mx, my = pointAt(p)
			local closest, closestDist = nil, 14
			for i, pt in points do
				local kx = 6 + pt.X * (W - 12)
				local ky = 6 + (1 - pt.Y) * 88
				local distance = math.sqrt((mx - kx)^2 + (my - ky)^2)
				if distance < closestDist then
					closest, closestDist = i, distance
				end
			end
			if closest and closest > 1 and closest < #points then
				table.remove(points, closest)
				rebuildTangents()
				redraw()
				if o.Callback then o.Callback(object:Get()) end
				flow:changed()
			else
				object:Set(defaultPoints)
				triggerFlash(entry)
			end
		end,
		tip = o.Tip ~= false and { text, o.Tip or "Click the curve to add points, drag to move them, and right-click a point to remove it. Right-click elsewhere to reset." } or nil,
	})

	self:flag(o, text, function()
		local out = {}
		for _, pt in points do table.insert(out, { X = pt.X, Y = pt.Y }) end
		return out
	end, function(v)
		if type(v) == "table" then
			local loaded = {}
			for _, item in v do
				if type(item) == "table" and item.X and item.Y then
					table.insert(loaded, Vector2.new(item.X, item.Y))
				end
			end
			if #loaded > 0 then object:Set(loaded, true) end
		end
	end)

	redraw()
	attachDependsOn(object, rowData)
	self:advance(126)
	return object
end

-- A row with a chevron that opens a card beside itself.
function Flow:SubMenu(o)
	self:rowBegin()
	local W, scope, level, top = self.rw, self.scope, self.level, self.y
	local row = Box(self.parent, self.x, top, W, 25)
	self:registerRow(row, 25, self.lastSep)
	local entry = self:note(o.Name)
	local t = Anim(0, 15)
	local chevron = Glyph(row, "CHEVRON_RIGHT", 14)
	chevron:center(W - 4 - chevron.boxW * 0.5, 12.5)
	local label = ScrollText(row, 0, 0, W - 4 - chevron.boxW - 8, 25, 12, nil, scope)
	local isUp, hovered = false, false
	local function paint()
		local a = scope.alpha
		local color = flashColor(T.Disabled:Lerp(T.Text, t.v), entry)
		label:set(tr(o.Name))
		label:paint(color, a)
		chevron:paint(color, a)
	end
	t.cb = paint
	if entry then entry.paint = paint end
	scope:paint(paint)
	local width = o.Width or 240
	local flow = self
	local card
	local function ensure()
		if card then return card end
		card = newCard({
			width = width, name = o.Name,
			build = function(c)
				local title = Label(c.content, "", 13, capY(20, 14), 14, FontSemi)
				c.scope:paint(function()
					setText(title, tr(o.Name), 14, FontSemi)
					title.TextColor3, title.TextTransparency = T.Text, 1 - c.scope.alpha
				end)
				local inner = newFlow({ parent = c.content, scope = c.scope, x = 10, y = 36, w = width - 20, rw = min(240, width - 20), card = c, level = c.level, win = flow.win, path = flow.path .. "/" .. o.Name, store = flow.store })
				o.Build(inner)
				c:setHeight(inner:bottom() + 10)
			end,
			place = function(c, click) return placeBeside(c, click) end,
		})
		card.onState = function(state)
			isUp = state
			t:to((state or hovered) and 1 or 0)
		end
		return card
	end
	Hit(scope, row, {
		hover = function(b)
			hovered = b
			t:to((b or isUp) and 1 or 0)
			label:hover(b)
		end,
		click = function(p)
			if o.Callback then o.Callback() end
			if o.Build then ensure():open(level, toStage(p)) end
		end,
		tip = { o.Name, o.Tip or "Open this section to adjust its settings." },
	})
	self:advance(25)
	return { card = ensure }
end

-- A row of its own: label left, colour swatch right.
function Flow:Color(o)
	self:rowBegin()
	local W, scope, top = self.rw, self.scope, self.y
	local row = Box(self.parent, self.x, top, W, 25)
	self:registerRow(row, 25, self.lastSep)
	local entry = self:note(o.Name)
	local t = Anim(0, 15)
	local colorObject = self:makeSwatch(row, W - 15, 5, o.Color or (o.Slots and o.Slots[1].value) or newColor(White), { name = o.Name, slots = o.Slots, extras = o.Extras, onChange = o.Callback })
	local label = ScrollText(row, 0, 0, W - 15 - 8, 25, 12, nil, scope)
	local function paint()
		local color = flashColor(T.Disabled:Lerp(T.Text, t.v), entry)
		label:set(tr(o.Name))
		label:paint(color, scope.alpha)
	end
	t.cb = paint
	if entry then entry.paint = paint end
	scope:paint(paint)
	Hit(scope, row, {
		hover = function(b) t:to(b and 1 or 0); label:hover(b) end,
		tip = { o.Name, o.Tip or (o.Slots and "Click the swatch to edit the colors." or "Click the swatch to edit the color.") },
	})
	self:advance(25)
	return colorObject
end

--[[ ---------------------------------------- Popup rows ------------------------------------ ]]

function Flow:Separator()
	local line = Box(self.parent, self.x, self.y + 6, self.rw, 1, T.PopupBorder)
	local scope = self.scope
	scope:paint(function()
		line.BackgroundColor3, line.BackgroundTransparency = T.PopupBorder, 1 - 0.55 * scope.alpha
	end)
	self:registerRow(nil, 13, nil, nil, 0, function(y)
		setXY(line, self.x, y + 6)
		setWH(line, self.rw, 1)
	end)
	self.y += 13
	self.trail = 0
end

function Flow:Space(height)
	assert(type(height) == "number" and height >= 0, "Space height must be non-negative")
	self:registerRow(nil, height, nil, nil, 0)
	self.y += height
end

-- A group inside a card, built like the menu's own group boxes: an inset panel, rows divided by
-- hairlines. Border = false gives plain rows with no panel.
function Flow:Section(o, build)
	if o.Collapsible then
		self:rowBegin()
		local W, top = self.rw, self.y
		local scope, card = self.scope, self.card
		local headerH, inset = 25, o.Inset or 12
		local opened = o.DefaultOpen ~= false
		local row = Box(self.parent, self.x, top, W, headerH)
		row.ClipsDescendants = true
		local rowData = self:registerRow(row, headerH, self.lastSep)
		local header = Box(row, 0, 0, W, headerH, T.FrameInactive, 6)
		local title = Label(header, tr(o.Name or "Section"), 9, capY(headerH * 0.5, 11), 11, FontSemi)
		title.Size = UDim2.new(1, -28, 0, 16)
		local arrowDown = chevronShape(header, false):at(W - 11, headerH * 0.5)
		local arrowUp = chevronShape(header, true):at(W - 11, headerH * 0.5)
		local panel = Box(row, 0, headerH, W, 0, T.Body, 8)
		panel.ClipsDescendants = true
		local panelLine = Stroke(panel, T.Border)
		local inner = newFlow({
			parent = panel, scope = scope, x = inset, y = o.Pad or 6, w = W - inset * 2, rw = W - inset * 2,
			spacing = 4, separators = true, card = card, level = self.level, win = self.win, path = self.path, store = self.store,
			hostRight = function()
				local a = toStage(card.frame.AbsolutePosition)
				return a.X + card.width
			end,
		})
		table.insert(self.children, inner)
		build(inner)
		local bodyH = max(0, inner:bottom() + (o.Pad or 6))
		local visibleHeight = headerH + (opened and bodyH or 0)
		rowData.height = visibleHeight
		setWH(panel, W, opened and bodyH or 0)
		local function paint()
			local a = scope.alpha
			header.BackgroundColor3, header.BackgroundTransparency = T.FrameInactive, 1 - 0.8 * a
			title.TextColor3, title.TextTransparency = T.Title, 1 - a
			setText(title, tr(o.Name or "Section"), 11, FontSemi)
			panel.BackgroundColor3, panel.BackgroundTransparency = T.Body, 1 - a
			panelLine.Color, panelLine.Transparency = T.Border, 1 - a
			arrowDown:paint(T.Text, a * (1 - (opened and 1 or 0)))
			arrowUp:paint(T.Text, a * (opened and 1 or 0))
		end
		scope:paint(paint)
		local expansion = Anim(opened and 1 or 0, 14, function(v)
			rowData.height = headerH + round(bodyH * v)
			rowData.heightScale = 1
			setWH(panel, W, round(bodyH * v))
			self:relayout()
			paint()
		end)
		local selfFlow = self
		local object = {}
		function object:SetExpanded(state, instantly)
			opened = state == true
			if instantly then
				expansion:set(opened and 1 or 0)
				rowData.height = headerH + (opened and bodyH or 0)
				rowData.heightScale = 1
				setWH(panel, W, opened and bodyH or 0)
				selfFlow:relayout()
			else
				expansion:to(opened and 1 or 0)
			end
			paint()
		end
		function object:IsExpanded() return opened end
		Hit(scope, header, {
			hover = function(state) header.BackgroundColor3 = state and T.FrameHovered or T.FrameInactive end,
			click = function() object:SetExpanded(not opened) end,
		})
		rowData.onResize = function(factor)
			W *= factor
			setWH(row, W, row.Size.Y.Offset)
			setWH(header, W, headerH)
			title.Size = UDim2.new(1, -28, 0, 16)
			arrowDown:at(W - 11, headerH * 0.5)
			arrowUp:at(W - 11, headerH * 0.5)
			setWH(panel, W, panel.Size.Y.Offset)
		end
		self:advance(visibleHeight)
		return object
	end
	local panel = o.Border ~= false
	local padY = panel and (o.Pad or 6) or 0
	local inset = o.Inset or (panel and 12 or 4)
	local top = self.y
	local scope, card = self.scope, self.card
	local plate, stroke, plateLine
	local container = Box(self.parent, self.x, top, self.w, 10)
	if panel then
		plate = Box(container, 0, 0, self.w, 10, T.Body, 10)
		plateLine = Box(container, 1, 1, self.w - 2, 8, nil, 9)
		stroke = Stroke(plateLine, T.Border)
		scope:paint(function()
			plate.BackgroundColor3, plate.BackgroundTransparency = T.Body, 1 - scope.alpha
			stroke.Color, stroke.Transparency = T.Border, 1 - scope.alpha
		end)
	end
	local rowData = self:registerRow(container, 0, nil, nil, 8)
	local inner = newFlow({
		parent = container, scope = scope, x = inset, y = padY, w = self.w - inset * 2, rw = self.w - inset * 2,
		spacing = panel and 4 or 0, separators = panel, card = card, level = self.level, win = self.win, path = self.path, store = self.store,
		hostRight = function()
			local a = toStage(card.frame.AbsolutePosition)
			return a.X + card.width
		end,
	})
	table.insert(self.children, inner)
	build(inner)
	local contentEnd = inner.y - (inner.started and inner.spacing or 0)
	local total = contentEnd + padY
	rowData.height = total
	setWH(container, self.w, total)
	if panel then
		setWH(plate, self.w, total)
		setWH(plateLine, self.w - 2, total - 2)
	end
	rowData.onResize = function(factor)
		local width = self.w
		setWH(container, width, total)
		if plate then
			setWH(plate, width, total)
			setWH(plateLine, width - 2, total - 2)
		end
	end
	self.y = top + total + 8
	self.trail = 8
end

function Flow:Text(o)
	self:rowBegin()
	local W, top, scope = self.rw, self.y, self.scope
	local height = o.Height or 22
	assert(type(height) == "number" and height > 0, "Text Height must be positive")
	local row = Box(self.parent, self.x, top, W, height)
	self:registerRow(row, height, self.lastSep)
	local label = New("TextLabel", {
		BackgroundTransparency = 1, FontFace = o.Bold and FontSemi or FontRegular, TextSize = o.Size or 12,
		TextXAlignment = o.Align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = o.Wrap == true, ClipsDescendants = true, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(1, 1),
	}, row)
	local value = tostring(o.Text or o.Name or "")
	local function paint()
		setText(label, tr(value), o.Size or 12, o.Bold and FontSemi or FontRegular)
		label.Size = UDim2.new(1, 0, 1, 0)
		label.TextColor3, label.TextTransparency = o.Color or T.Text, 1 - scope.alpha
	end
	scope:paint(paint)
	local object = {}
	function object:Get() return value end
	function object:Set(text)
		value = tostring(text)
		paint()
	end
	self:advance(height)
	return object
end

function Flow:Status(o)
	self:rowBegin()
	local W, top, scope = self.rw, self.y, self.scope
	local row = Box(self.parent, self.x, top, W, 26)
	local rowData = self:registerRow(row, 26, self.lastSep)
	local entry = self:note(o.Name)
	local label = ScrollText(row, 0, 0, max(1, W - 82), 26, 12, nil, scope)
	local badgeW = min(112, max(52, measure(tr(tostring(o.Default or "Ready")), 10) + 18))
	local badge = Box(row, W - badgeW, 3, badgeW, 20, T.FrameInactive, 6)
	local badgeText = Label(badge, "", 5, capY(10, 10), 10, FontMedium)
	badgeText.Position = UDim2.new(0, 5, 0, 0)
	badgeText.Size = UDim2.new(1, -10, 1, 0)
	badgeText.TextXAlignment = Enum.TextXAlignment.Center
	badgeText.TextYAlignment = Enum.TextYAlignment.Center
	local value = tostring(o.Default or "Ready")
	local function statusColor()
		if o.Color then return o.Color end
		local key = string.lower(value)
		if key == "success" or key == "ready" or key == "connected" or key == "online" then return T.Success end
		if key == "warning" or key == "pending" or key == "loading" then return T.Warning end
		if key == "error" or key == "failed" or key == "offline" then return T.Error end
		return T.Info
	end
	local function paint()
		local a = scope.alpha
		label:set(tr(o.Name))
		label:paint(flashColor(T.Text, entry), a)
		badge.BackgroundColor3, badge.BackgroundTransparency = statusColor(), 1 - 0.18 * a
		badgeText.TextColor3, badgeText.TextTransparency = T.Text, 1 - a
		setText(badgeText, tr(value), 10, FontMedium)
		badgeText.Size = UDim2.new(1, -10, 1, 0)
	end
	scope:paint(paint)
	local flow, object = self, {}
	function object:Get() return value end
	function object:Set(newValue, silent)
		value = tostring(newValue)
		badgeW = min(112, max(52, measure(tr(value), 10) + 18))
		setXY(badge, W - badgeW, 3)
		setWH(badge, badgeW, 20)
		paint()
		if o.Callback and not silent then o.Callback(value) end
		flow:changed()
	end
	rowData.onResize = function(factor)
		W *= factor
		label:width(max(1, W - badgeW - 8))
		setXY(badge, W - badgeW, 3)
	end
	if entry then entry.paint = paint end
	self:flag(o, o.Name, function() return value end, function(saved)
		if saved ~= nil then object:Set(saved, true) end
	end)
	self:advance(26)
	return object
end

function Flow:Progress(o)
	self:rowBegin()
	local W, top, scope = self.rw, self.y, self.scope
	local lo, hi = o.Min or 0, o.Max or 100
	assert(type(lo) == "number" and type(hi) == "number" and lo == lo and hi == hi and abs(lo) < huge and abs(hi) < huge and lo < hi, "Progress requires finite Min < Max")
	local initial = tonumber(o.Default) or lo
	assert(initial == initial and abs(initial) < huge, "Progress Default must be finite")
	local value = clamp(initial, lo, hi)
	local row = Box(self.parent, self.x, top, W, 34)
	local rowData = self:registerRow(row, 34, self.lastSep)
	local entry = self:note(o.Name)
	local label = ScrollText(row, 0, 0, W - 50, 16, 11, nil, scope)
	local valueLabel = Label(row, "", W - 48, capY(8, 10), 10, FontMedium)
	valueLabel.Size = UDim2.new(0, 48, 0, 14)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	local track = Box(row, 0, 19, W, 8, T.FrameInactive, 4)
	local fill = Box(track, 0, 0, W, 8, Accent, 4)
	local function paint()
		local a = scope.alpha
		label:set(tr(o.Name))
		label:paint(flashColor(T.Text, entry), a)
		valueLabel.TextColor3, valueLabel.TextTransparency = T.Disabled, 1 - a
		setText(valueLabel, o.Format and string.format(o.Format, value) or string.format("%g%%", (value - lo) / (hi - lo) * 100), 10, FontMedium)
		track.BackgroundColor3, track.BackgroundTransparency = T.FrameInactive, 1 - a
		fill.BackgroundColor3, fill.BackgroundTransparency = Accent, 1 - a
		setWH(fill, round(W * (value - lo) / (hi - lo)), 8)
	end
	scope:paint(paint)
	local flow, object = self, {}
	function object:Get() return value end
	function object:Set(newValue, silent)
		assert(type(newValue) == "number" and newValue == newValue, "Progress:Set expects a number")
		value = clamp(newValue, lo, hi)
		paint()
		if o.Callback and not silent then o.Callback(value) end
		flow:changed()
	end
	rowData.onResize = function(factor)
		W *= factor
		label:width(max(1, W - 50))
		setXY(valueLabel, W - 48, capY(8, 10))
		setWH(track, W, 8)
		paint()
	end
	if entry then entry.paint = paint end
	self:flag(o, o.Name, function() return value end, function(saved)
		if type(saved) == "number" then object:Set(saved, true) end
	end)
	self:advance(34)
	return object
end

function Flow:DataTable(o)
	self:rowBegin()
	local columns, data = o.Columns, o.Data or {}
	assert(type(columns) == "table" and #columns > 0, "DataTable Columns must be a non-empty array")
	assert(type(data) == "table", "DataTable Data must be an array")
	local flow = self
	local W, top, scope = self.rw, self.y, self.scope
	local height, rowH, headerH = o.Height or 170, o.RowHeight or 25, 24
	assert(type(height) == "number" and height == height and height < huge and height >= headerH + 1 and type(rowH) == "number" and rowH == rowH and rowH > 0 and rowH < huge, "DataTable dimensions are invalid")
	local viewportH = height - headerH
	local selected, scrollY = nil, 0
	local row = Box(self.parent, self.x, top, W, height)
	local rowData = self:registerRow(row, height, self.lastSep)
	local entry = self:note(o.Name)
	local header = Box(row, 0, 0, W, headerH, T.FrameInactive, 5)
	local body = Box(row, 0, headerH, W, viewportH)
	body.ClipsDescendants = true
	local empty = Label(body, tr(o.EmptyText or "No rows"), 8, capY(16, 11), 11)
	empty.TextColor3 = T.Disabled
	empty.Visible = false
	local columnWidths, headerLabels = {}, {}
	local totalFixed = 0
	for _, column in columns do
		if type(column) == "table" and column.Width ~= nil then
			assert(type(column.Width) == "number" and column.Width > 0 and column.Width < huge, "DataTable column widths must be finite and positive")
			totalFixed += column.Width
		end
	end
	assert(totalFixed < huge, "DataTable column widths are too large")
	local flexible = 0
	for _, column in columns do
		if type(column) ~= "table" or type(column.Width) ~= "number" then flexible += 1 end
	end
	local function layoutColumns()
		local fixedScale = totalFixed > W and W / totalFixed or 1
		local remaining = max(0, W - totalFixed * fixedScale)
		local x = 0
		for i, column in columns do
			local colW = type(column) == "table" and column.Width or nil
			if colW then colW *= fixedScale else colW = flexible > 0 and remaining / flexible or W / #columns end
			columnWidths[i] = colW
			if headerLabels[i] then
				setXY(headerLabels[i], round(x + 7), capY(headerH * 0.5, 10))
				setWH(headerLabels[i], max(1, round(colW - 12)), 14)
			end
			x += colW
		end
	end
	for i, column in columns do
		local name = type(column) == "table" and column.Name or column
		assert(type(name) == "string", "DataTable column names must be strings")
		local label = Label(header, tr(name), 0, 0, 10, FontSemi)
		label.TextTruncate = Enum.TextTruncate.AtEnd
		headerLabels[i] = label
	end
	local visibleCount = ceil(viewportH / rowH) + 1
	local pool = {}
	local function cellValue(item, column)
		if type(column) == "table" and type(column.Get) == "function" then return tostring(column.Get(item)) end
		local key = type(column) == "table" and (column.Key or column.Name) or column
		local value = type(item) == "table" and item[key] or nil
		return value == nil and "" or tostring(value)
	end
	local render
	for i = 1, visibleCount do
		local frame = Box(body, 0, 0, W, rowH, T.Body, 3)
		local border = Stroke(Box(frame, 0, 0, W, rowH, nil, 3), T.Border)
		local labels = {}
		for j = 1, #columns do
			local label = Label(frame, "", 0, capY(rowH * 0.5, 10), 10)
			label.TextTruncate = Enum.TextTruncate.AtEnd
			labels[j] = label
		end
		local slot = { frame = frame, border = border, labels = labels }
		pool[i] = slot
		Hit(scope, frame, {
			hover = function(state) slot.hovered = state end,
			click = function()
				if slot.index and data[slot.index] ~= nil then
					selected = slot.index
					if o.Callback then o.Callback(data[selected], selected) end
					render()
					flow:changed()
				end
			end,
		})
	end
	local function paint()
		local a = scope.alpha
		header.BackgroundColor3, header.BackgroundTransparency = T.FrameInactive, 1 - a
		for _, label in headerLabels do
			label.TextColor3, label.TextTransparency = T.Text, 1 - a
		end
		for _, slot in pool do
			slot.frame.BackgroundColor3 = slot.index == selected and T.FrameActive or T.Body
			slot.frame.BackgroundTransparency = 1 - a
			slot.border.Color = slot.index == selected and Accent or T.Border
			slot.border.Transparency = 1 - (slot.index == selected and 0.8 or 0.5) * a
			for _, textLabel in slot.labels do
				textLabel.TextColor3, textLabel.TextTransparency = T.Text, 1 - a
			end
		end
	end
	render = function()
		local count = #data
		scrollY = clamp(scrollY, 0, max(0, count * rowH - viewportH))
		local first = floor(scrollY / rowH) + 1
		local offset = scrollY % rowH
		for i, slot in pool do
			local index = first + i - 1
			slot.index = index <= count and index or nil
			slot.frame.Visible = slot.index ~= nil
			if slot.index then
				setXY(slot.frame, 0, (i - 1) * rowH - offset)
				for columnIndex, textLabel in slot.labels do
					local x = 0
					for j = 1, columnIndex - 1 do x += columnWidths[j] end
					setXY(textLabel, round(x + 7), capY(rowH * 0.5, 10))
					setWH(textLabel, max(1, round(columnWidths[columnIndex] - 12)), 14)
					setText(textLabel, cellValue(data[index], columns[columnIndex]), 10)
				end
			end
		end
		empty.Visible = count == 0
		empty.TextColor3, empty.TextTransparency = T.Disabled, 1 - scope.alpha
		paint()
		scope:invalidateGrid(true)
	end
	local object = {}
	function object:GetData() return table.clone(data) end
	function object:GetSelection() return selected and data[selected] or nil, selected end
	function object:Select(index, silent)
		assert(index == nil or (type(index) == "number" and index % 1 == 0 and data[index] ~= nil), "DataTable selection is out of range")
		selected = index
		render()
		if selected and o.Callback and not silent then o.Callback(data[selected], selected) end
	end
	function object:SetData(newData)
		assert(type(newData) == "table", "DataTable:SetData expects an array")
		data = table.clone(newData)
		if selected and data[selected] == nil then selected = nil end
		render()
	end
	Wheel(scope, body, function(direction)
		scrollY = clamp(scrollY - direction * rowH * 3, 0, max(0, #data * rowH - viewportH))
		render()
	end)
	rowData.onResize = function(factor)
		W *= factor
		layoutColumns()
		setWH(header, W, headerH)
		setWH(body, W, viewportH)
		setWH(empty, W - 16, 18)
		for _, slot in pool do setWH(slot.frame, W, rowH) end
		render()
	end
	scope:paint(paint)
	if entry then entry.paint = paint end
	layoutColumns()
	render()
	self:advance(height)
	return object
end

function Flow:rowImpl(icon, label, lit, deferred)
	local W, scope, top = self.rw, self.scope, self.y
	local row = Box(self.parent, self.x, top, W, 33)
	self:registerRow(row, 33, nil, nil, 0)
	local t = Anim(0, 15)
	local lx = 4
	local glyph
	if icon then
		glyph = Glyph(row, icon, 14)
		glyph:center(15, 16.5)
		lx = 4 + 22 + 10
	end
	local text = Label(row, "", lx, capY(16.5, 12), 12)
	local hovered, active = false, lit or false
	local handlers = { hover = function(b) hovered = b; t:to((b or active) and 1 or 0) end }
	local state = { row = row, t = t, top = top, W = W, handlers = handlers, setLit = function(on) active = on; t:to((on or hovered) and 1 or 0) end }
	local extra
	local function paint()
		local a = scope.alpha
		if glyph then glyph:paint(T.Disabled:Lerp(T.Text, t.v * 0.6), a) end
		setText(text, tr(label), 12)
		text.TextColor3, text.TextTransparency = T.Text, 1 - a * (0.8 + 0.2 * t.v)
		if extra then extra() end
	end
	t.cb = paint
	state.setExtra = function(fn) extra = fn end
	state.paint = paint
	state.labelEnd = function() return lx + measure(tr(label), 12) end
	if not deferred then scope:paint(paint) end
	self.y += 33
	self.trail = 0
	return state
end

function Flow:Row(icon, label, callback)
	local r = self:rowImpl(icon, label, false)
	r.handlers.click = callback
	Hit(self.scope, r.row, r.handlers)
	return r
end

function Flow:PopupToggle(icon, label, default, callback)
	local r = self:rowImpl(icon, label, false, true)
	local value = default == true
	local on = Anim(value and 1 or 0, 12)
	local paintSwitch = Switch(r.row, r.W - 4 - 30, 7, self.scope)
	local flow = self
	local object = {}
	r.setExtra(function() paintSwitch(on.v) end)
	on.cb = r.paint
	self.scope:paint(r.paint)
	function object:Set(state, silent)
		value = state == true
		on:to(value and 1 or 0)
		if callback and not silent then callback(value) end
		flow:changed()
	end
	function object:Get() return value end
	r.handlers.click = function() object:Set(not value) end
	Hit(self.scope, r.row, r.handlers)
	self:flag({}, label, function() return value end, function(v) object:Set(v == true) end)
	return object
end

local function choiceWidth(options)
	local widest = 0
	for _, option in options do widest = max(widest, measure(tr(option), 12)) end
	return ceil(max(170, widest + 64))
end

local function checkContours()
	local sz = 9
	local thickness = max(sz / 5, 1)
	sz -= thickness * 0.5
	local p = thickness * 0.25
	local third = sz / 3
	local bx, by = p + third, p + sz - third * 0.5
	return strokeContours({ bx - third, by - third, bx, by, bx + third * 2, by - third * 2 }, thickness)
end

-- Rows of a little option card: a sliding check, the label pushed along behind it.
local function choiceRows(c, flowW, options, isSelected, onPick, startY)
	local rows = {}
	for i, option in options do
		local row = Box(c.content, 10, startY + (i - 1) * 33, flowW, 33)
		local plate = Box(row, 0, 0, flowW, 33, T.FrameInactive, 6)
		local check = Shape(row, checkContours(), 1, "CHECKMARK")
		check:at(10, 12)
		local t, hover = Anim(isSelected(i) and 1 or 0, 18), Anim(0, 15)
		local label = Label(row, "", 10, capY(16.5, 12), 12)
		local function paint()
			local a = c.scope.alpha
			plate.BackgroundColor3, plate.BackgroundTransparency = T.FrameInactive, 1 - hover.v * 0.6 * a
			check:paint(T.Text, t.v * a)
			setXY(label, round(10 + 22 * t.v), capY(16.5, 12))
			setText(label, tr(option), 12)
			label.TextColor3, label.TextTransparency = T.Disabled:Lerp(T.Text, max(t.v, hover.v)), 1 - a
		end
		t.cb, hover.cb = paint, paint
		c.scope:paint(paint)
		Hit(c.scope, row, {
			hover = function(b) hover:to(b and 1 or 0) end,
			click = function() onPick(i) end,
		})
		rows[i] = function() t:to(isSelected(i) and 1 or 0) end
	end
	return rows
end

local function optionCard(flow, options, getIndex, setIndex, rowTop, onState)
	local card, rows
	local width = choiceWidth(options)
	card = newCard({
		width = width, name = "OptionCard",
		build = function(c)
			rows = choiceRows(c, width - 20, options, function(i) return i == getIndex() end, function(i)
				setIndex(i)
				for _, r in rows do r() end
			end, 10)
			c:setHeight(20 + #options * 33)
		end,
		place = function(c)
			local at = toStage(flow.card.frame.AbsolutePosition)
			return keepOnScreen(c, at.X + flow.card.width + 8, at.Y + rowTop - 10)
		end,
	})
	card.onState = onState
	return card
end

function Flow:Option(icon, label, options, default, callback)
	local r = self:rowImpl(icon, label, false, true)
	local index = default or 1
	local chevron = Glyph(r.row, "CHEVRON_RIGHT", 13)
	local chevX = r.W - 4 - chevron.boxW
	chevron:center(chevX + chevron.boxW * 0.5, 16.5)
	local value = New("TextLabel", {
		Text = "", BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12, Size = UDim2.fromOffset(120, 16), TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(round(chevX - 6 - 120), capY(16.5, 12)), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top,
	}, r.row)
	local scope = self.scope
	r.setExtra(function()
		local color = T.Disabled:Lerp(T.Text, r.t.v * 0.6)
		chevron:paint(color, scope.alpha)
		-- a long value stops short of the row's own label
		local right = round(chevX - 6)
		local room = max(20, right - ceil(r.labelEnd()) - 12)
		setWH(value, room, 16)
		setXY(value, right - room, capY(16.5, 12))
		value.Text = tr(options[index])
		value.TextColor3, value.TextTransparency = color, 1 - scope.alpha
	end)
	scope:paint(r.paint)
	local flow = self
	local object = {}
	function object:Get() return options[index], index end
	function object:Set(i, silent)
		index = i
		r.paint()
		if callback and not silent then callback(options[index], index) end
		flow:changed()
	end
	local card
	r.handlers.click = function()
		if not card then
			card = optionCard(flow, options, function() return index end, function(i) object:Set(i) end, r.top, function(state) r.setLit(state) end)
		end
		card:open(flow.level)
	end
	Hit(scope, r.row, r.handlers)
	self:flag({}, label, function() return options[index] end, function(v)
		local i = table.find(options, v)
		if i then object:Set(i) end
	end)
	return object
end

--[[ ---------------------------------------- Shared bits ----------------------------------- ]]

local function IconButton(parent, scope, name, x, y, w, h, colors, onClick, plate)
	local holder = Box(parent, x, y, w, h)
	local glyph = Glyph(holder, name, 14)
	glyph:center(w * 0.5, h * 0.5)
	local t = Anim(0, 15)
	local function paint()
		local idle, hot = colors()
		glyph:paint(idle:Lerp(hot, t.v), scope.alpha)
		if plate then plate(t.v) end
	end
	t.cb = paint
	scope:paint(paint)
	Hit(scope, holder, { hover = function(b) t:to(b and 1 or 0) end, click = onClick })
	return holder, paint, glyph
end

local function DimHot() return T.Disabled, T.Text end

-- Icon + label rows of the small popup menus.
local function MenuRow(c, y, width, icon, label, colors, onClick)
	local row = Box(c.content, 10, y, width, 33)
	local glyph = Glyph(row, icon, 14)
	glyph:center(10 + glyph.boxW * 0.5, 16.5)
	local text = Label(row, "", 36, capY(16.5, 12), 12)
	local t = Anim(0, 15)
	local function paint()
		local idle, hot = colors()
		local color = idle:Lerp(hot, t.v)
		glyph:paint(color, c.scope.alpha)
		setText(text, tr(label), 12)
		text.TextColor3, text.TextTransparency = color, 1 - c.scope.alpha
	end
	t.cb = paint
	c.scope:paint(paint)
	Hit(c.scope, row, { hover = function(b) t:to(b and 1 or 0) end, click = onClick })
end

local Avatar = {}
do
	local head, body = {}, {}
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		table.insert(head, 15 + math.cos(a) * 6)
		table.insert(head, 12 + math.sin(a) * 6)
	end
	-- the shoulders are a circle cropped by the avatar's own circular mask
	local steps = 20
	local s0 = math.asin(11.25 / 15.16)
	for i = 0, steps do
		local a = -s0 + 2 * s0 * i / steps
		table.insert(body, 15 + math.sin(a) * 15.16)
		table.insert(body, 34.66 - math.cos(a) * 15.16)
	end
	local e0 = math.acos(9.5 / 15)
	for i = 1, steps - 1 do
		local a = e0 - 2 * e0 * i / steps
		table.insert(body, 15 + math.sin(a) * 15)
		table.insert(body, 15 + math.cos(a) * 15)
	end
	function Avatar.new(parent, x, y, size, scope)
		local unit = size / 30
		local shape = Shape(parent, { head, body }, unit, "AVATAR" .. size)
		shape:at(x, y)
		scope:paint(function() shape:paint(Color3.fromRGB(130, 133, 143), scope.alpha) end)
		return shape
	end
end

--[[ ---------------------------------------- Notifications --------------------------------- ]]

local Notes, NoteLayer = {}, nil

local function pushNotification(title, message)
	if not NoteLayer then
		NoteLayer = Box(Stage, 0, 0, 0, 0)
		NoteLayer.Size = UDim2.fromScale(1, 1)
		NoteLayer.ZIndex = 200000
	end
	local frame = Box(NoteLayer, 0, 0, 280, 72)
	local bg = Box(frame, 0, 0, 280, 72, Color3.fromRGB(8, 9, 16), 10)
	local shadow = Shadow(bg, 16, 0.55, 3)
	local line = Stroke(Box(bg, 1, 1, 278, 70, nil, 9), White)
	-- Task 3.1: Specular rim stroke & top Accent bar
	local rimFrame = Box(bg, 1, 1, 278, 70, nil, 9)
	local rimStroke = Stroke(rimFrame, White, 1)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(1, 1.0),
		}),
	}, rimStroke)
	local topGlow = Box(frame, 2, 1, 276, 2, Accent, 1)
	local logo = Box(frame, 12, 14, 44, 44, Black, 10)
	local cog = Glyph(logo, "COG", 14)
	cog:center(22, 22)
	local head = Label(frame, title, 68, capY(26, 12), 12)
	local body = Label(frame, message, 68, capY(46, 12), 12)
	local barBack = Box(frame, 4, 67, 272, 3, Color3.fromRGB(30, 35, 50), 1)
	local bar = Box(frame, 4, 67, 272, 3, Accent, 1)
	local note = { frame = frame, age = 0, offset = 1 }
	table.insert(Notes, note)
	Run(function(dt)
		note.age += dt
		local age = note.age
		note.offset += (0 - note.offset) * clamp(dt * 6, 0, 1)
		local alpha = 1
		if age < 0.15 then alpha = age / 0.15 end
		if age > 3 then alpha = 1 - (age - 3) end
		alpha = sat(alpha)
		local index = table.find(Notes, note)
		local view = viewport()
		setXY(frame, round(view.X - 280 - 12 + note.offset * 300), 12 + 80 * (index - 1))
		if shadow then shadow.Transparency = 1 - 0.45 * alpha end
		bg.BackgroundTransparency = 1 - alpha
		line.Transparency = 1 - (8 / 255) * alpha
		logo.BackgroundTransparency = 1 - alpha
		cog:paint(White, alpha)
		head.TextColor3, head.TextTransparency = White, 1 - alpha
		body.TextColor3, body.TextTransparency = Color3.fromRGB(130, 132, 143), 1 - alpha
		barBack.BackgroundTransparency = 1 - (120 / 255) * alpha
		bar.BackgroundColor3, bar.BackgroundTransparency = Accent, 1 - alpha
		setWH(bar, round(272 * sat(1 - age / 3)), 3)
		if age > 4 then
			table.remove(Notes, index)
			frame:Destroy()
			return false
		end
		return true
	end, Root)
end

--[[ ---------------------------------------- Tabs and boxes -------------------------------- ]]

local TabMeta = {}
TabMeta.__index = TabMeta

function TabMeta:Columns(weights)
	assert(type(weights) == "table" and type(weights[1]) == "number" and type(weights[2]) == "number", "Columns expects two numeric weights")
	assert(weights[1] > 0 and weights[1] < huge and weights[2] > 0 and weights[2] < huge, "Column weights must be finite and positive")
	assert(weights[3] == nil, "Only two columns are supported")
	self.weights = { weights[1], weights[2] }
end

function TabMeta:Box(o)
	local win, page = self.win, self.content
	local column = o.Column or 1
	assert(column == 1 or column == 2, "Box.Column must be 1 or 2")
	local box = { name = o.Name, column = column, height = o.Height or "auto", tab = self, spacing = o.RowSpacing or 8, padY = o.PadY or 8 }
	local holder = Box(page, 0, 0, 100, 100)
	local fill = Box(holder, 0, 18, 100, 80, T.Group, 13)
	local lineFrame = Box(holder, 1, 19, 98, 78, nil, 12)
	local line = Stroke(lineFrame, T.Border)
	-- Task 3.1: Specular rim highlight on Group box
	local rimStroke = Stroke(lineFrame, White, 1)
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.86),
			NumberSequenceKeypoint.new(1, 1.0),
		}),
	}, rimStroke)
	local title = Label(holder, "", 12, 0, 11, FontSemi)
	local content = Box(holder, 0, 18, 100, 80)
	local scope = newScope(self.scope)
	local scroller
	local flow = newFlow({ parent = content, scope = scope, x = 12, y = box.padY, w = 100, rw = 100, spacing = box.spacing, separators = true, level = 0, win = win,
		path = self.name .. "/" .. o.Name, store = win.store, search = { win = win, tab = self, tabName = self.name, box = o.Name } })
	flow.hostRight = function()
		local a = toStage(holder.AbsolutePosition)
		return a.X + box.width
	end
	scope:paint(function()
		local a = scope.alpha
		fill.BackgroundColor3, fill.BackgroundTransparency = T.Group, 1 - a
		line.Color, line.Transparency = T.Border, 1 - a
		setText(title, tr(o.Name), 11, FontSemi)
		title.TextColor3, title.TextTransparency = T.Title, 1 - 0.5 * a
	end)
	box.holder, box.fill, box.lineFrame, box.content, box.flow, box.scope, box.title = holder, fill, lineFrame, content, flow, scope, title
	-- the widgets are built knowing the column width, which the column split decides
	local columns = self.weights
	local total = 0
	for i = 1, 2 do total += columns and columns[i] or 1 end
	local usable = win.width - 200 - 8
	local width = usable * (columns and columns[box.column] or 1) / total
	box.width = width
	flow.w, flow.rw = width - 24, width - 24
	flow.box = box
	setWH(holder, width, 100)
	setWH(fill, width, 80)
	setWH(lineFrame, width - 2, 78)
	setWH(content, width, 80)
	if o.Scrollable then
		content.ClipsDescendants = true
		scope.clip = content
		local inner = Box(content, 0, 0, width, 80)
		flow.parent = inner
		box.inner = inner
		scroller = { y = 0, max = 0 }
		box.scroller = scroller
		local fadeTop = Box(content, 0, 0, width, 40, White)
		local fadeBottom = Box(content, 0, 40, width, 40, White)
		local gTop = New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }, fadeTop)
		local gBottom = New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, fadeBottom)
		box.fadeTop, box.fadeBottom = fadeTop, fadeBottom

		-- Task 3.3: Interactive scrollbars with drag thumb
		local thumb = Box(content, width - 5, 0, 3, 20, T.Disabled, 2)
		local thumbHover = Anim(0, 15)
		local thumbDrag = false
		local thumbStartMouseY, thumbStartScrollerY = 0, 0
		local thumbFade = Anim(0, 15)
		local thumbTimer = 0
		local cancelThumbJob

		local function updateThumb()
			local viewH = box.content.Size.Y.Offset
			local natural = box.flow.y - box.spacing + box.padY + 18
			local contentH = natural - 18
			if scroller.max <= 0 or contentH <= viewH then
				thumb.Visible = false
				return
			end
			thumb.Visible = true
			local thumbRatio = clamp(viewH / max(contentH, 1), 0.12, 1)
			local thumbH = max(round(thumbRatio * viewH), 14)
			local maxThumbY = max(0, viewH - thumbH)
			local thumbY = round((scroller.y / max(scroller.max, 1)) * maxThumbY)
			setXY(thumb, box.width - 5, thumbY)
			setWH(thumb, 3, thumbH)
		end
		box.updateThumb = updateThumb

		local function paintThumb()
			local a = scope.alpha * max(thumbFade.v, thumbHover.v)
			local color = T.Disabled:Lerp(Accent, max(thumbHover.v, thumbDrag and 1 or 0))
			thumb.BackgroundColor3 = color
			thumb.BackgroundTransparency = 1 - 0.85 * a
		end
		thumbHover.cb = paintThumb
		thumbFade.cb = paintThumb
		scope:paint(paintThumb)

		local function showThumbBriefly()
			thumbTimer = 1.0
			thumbFade:to(1)
			if cancelThumbJob then cancelThumbJob() end
			cancelThumbJob = Run(function(dt)
				thumbTimer -= dt
				if thumbTimer > 0 or thumbDrag or thumbHover.v > 0.01 then return true end
				thumbFade:to(0)
				cancelThumbJob = nil
				return false
			end, scope)
		end

		local function paintFades()
			local topStrength = sat(scroller.y / 40)
			local bottomStrength = sat((scroller.max - scroller.y) / 40)
			local color = T.Group
			fadeTop.BackgroundColor3, fadeBottom.BackgroundColor3 = color, color
			fadeTop.BackgroundTransparency = 1 - topStrength * scope.alpha
			fadeBottom.BackgroundTransparency = 1 - bottomStrength * scope.alpha
			updateThumb()
			paintThumb()
		end
		box.paintFades = paintFades
		scope:paint(paintFades)

		Wheel(scope, content, function(z)
			scroller.y = clamp(scroller.y - z * 75, 0, scroller.max)
			setXY(inner, 0, -scroller.y)
			scope:invalidateGrid(true)
			paintFades()
			showThumbBriefly()
		end)

		Hit(scope, thumb, {
			hover = function(b)
				thumbHover:to(b and 1 or 0)
				if b then showThumbBriefly() end
			end,
			down = function(p)
				thumbDrag = true
				thumbStartMouseY = toStage(p).Y
				thumbStartScrollerY = scroller.y
				paintThumb()
			end,
			drag = function(p)
				if not thumbDrag then return end
				local viewH = box.content.Size.Y.Offset
				local natural = box.flow.y - box.spacing + box.padY + 18
				local contentH = natural - 18
				local thumbRatio = clamp(viewH / max(contentH, 1), 0.12, 1)
				local thumbH = max(round(thumbRatio * viewH), 14)
				local maxThumbY = max(1, viewH - thumbH)
				local deltaY = toStage(p).Y - thumbStartMouseY
				scroller.y = clamp(thumbStartScrollerY + (deltaY / maxThumbY) * scroller.max, 0, scroller.max)
				setXY(inner, 0, -scroller.y)
				scope:invalidateGrid(true)
				paintFades()
				showThumbBriefly()
			end,
			up = function()
				thumbDrag = false
				paintThumb()
			end,
		})
	end
	table.insert(self.boxes, box)
	setmetatable(box, { __index = function(_, key)
		local method = Flow[key]
		if method then return function(_, ...) return method(flow, ...) end end
	end })
	return box
end

function TabMeta:layout()
	local columns = self.weights
	local total, widths = 0, {}
	for i = 1, 2 do total += columns and columns[i] or 1 end
	local viewW, viewH = self.win.width - 200, self.win.height - 91
	local usable = viewW - 8
	for i = 1, 2 do widths[i] = usable * (columns and columns[i] or 1) / total end
	setWH(self.page, viewW, viewH)
	setWH(self.content, viewW, viewH)

	local minimums, required = {}, { 0, 0 }
	for _, box in self.boxes do
		local natural = box.flow.y - box.spacing + box.padY + 18
		local minimum = box.height == "auto" and natural or (type(box.height) == "number" and max(box.height, 0) or 0)
		minimums[box] = minimum
		required[box.column] += minimum + 8
	end
	local gridH = max(viewH, required[1] - 8, required[2] - 8)
	local cursors = { 0, 0 }
	local trailing = { required[1], required[2] }
	for _, box in self.boxes do
		local i = box.column
		local natural = box.flow.y - box.spacing + box.padY + 18
		trailing[i] -= minimums[box] + 8
		local remaining = max(0, gridH - cursors[i] - trailing[i] - 2)
		local h
		if box.height == "auto" then
			h = natural
		elseif box.height > 0 then
			h = box.height
		elseif box.height < 0 then
			h = remaining * -box.height
		else
			h = remaining
		end
		h = floor(h)
		box.boxHeight = h
		local x = i == 1 and 0 or (widths[1] + 8)
		setXY(box.holder, floor(x), cursors[i])
		setWH(box.holder, box.width, h)
		setWH(box.fill, box.width, h - 18)
		setWH(box.lineFrame, box.width - 2, h - 20)
		setWH(box.content, box.width, h - 18)
		if box.scroller then
			local viewH = h - 18
			setWH(box.inner, box.width, max(natural - 18, viewH))
			box.scroller.max = max(0, natural - 18 - viewH)
			box.scroller.y = clamp(box.scroller.y, 0, box.scroller.max)
			setXY(box.inner, 0, -box.scroller.y)
			box.scope:invalidateGrid(true)
			setXY(box.fadeBottom, 0, viewH - min(40, viewH * 0.25))
			setWH(box.fadeTop, box.width, min(40, viewH * 0.25))
			setWH(box.fadeBottom, box.width, min(40, viewH * 0.25))
			box.paintFades()
		end
		cursors[i] += h + 8
	end
	local contentH = max(viewH, cursors[1] - 8, cursors[2] - 8)
	setWH(self.content, viewW, contentH)
	self.scrollMax = max(0, contentH - viewH)
	self.scrollY = clamp(self.scrollY, 0, self.scrollMax)
	setXY(self.content, 0, -self.scrollY)
	for _, box in self.boxes do box.scope:invalidateGrid(true) end
end

-- One line of a framed list: accent border while selected, optional trailing action.
function Flow:Framed(label, o)
	o = o or {}
	local W, scope, top = o.Width or self.rw, self.scope, self.y
	local row = Box(self.parent, self.x, top, W, 36)
	self:registerRow(row, 36, nil, nil, self.spacing)
	local fill = Box(row, 0, 0, W, 36, T.FrameInactive, 8)
	local lineFrame = Box(row, 1, 1, W - 2, 34, nil, 7)
	local line = Stroke(lineFrame, Accent)
	local icon, text = splitIcon(label)
	local textX = 12
	local glyph
	if icon then
		glyph = Glyph(row, icon, 14)
		glyph:center(12 + glyph.boxW * 0.5, 18)
		textX = round(12 + glyph.boxW + 8)
	end
	local name = Label(row, "", textX, capY(18, 12), 12)
	local hot, on = Anim(0, 15), Anim(o.Selected and 1 or 0, 14)
	local actionHot, actionFill, actionPaint, actionLabel, actionGlyph
	if o.ActionIcon or o.ActionLabel then
		actionHot = Anim(0, 15)
		local iconW = 0
		if o.ActionIcon then iconW = glyphContours(o.ActionIcon).adv / 512 * 14 end
		local labelW = o.ActionLabel and measure(tr(o.ActionLabel), 12) or 0
		local aw = iconW + labelW + (o.ActionIcon and o.ActionLabel and 6 or 0) + 16
		local ax = W - 6 - aw
		local action = Box(row, ax, 6, aw, 24)
		actionFill = Box(action, 0, 0, aw, 24, T.FrameInactive, 6)
		if o.ActionIcon then
			actionGlyph = Glyph(action, o.ActionIcon, 14)
			actionGlyph:center(8 + iconW * 0.5, 12)
		end
		if o.ActionLabel then
			actionLabel = Label(action, tr(o.ActionLabel), 8 + iconW + (o.ActionIcon and 6 or 0), capY(12, 12), 12)
		end
		actionPaint = function()
			local a = scope.alpha
			actionFill.BackgroundColor3, actionFill.BackgroundTransparency = T.FrameInactive, 1 - 0.8 * actionHot.v * a
			local color = T.Disabled:Lerp(T.Text, actionHot.v)
			if actionGlyph then actionGlyph:paint(color, a) end
			if actionLabel then actionLabel.TextColor3, actionLabel.TextTransparency = color, 1 - a end
		end
		actionHot.cb = actionPaint
		scope:paint(actionPaint)
		Hit(scope, action, { hover = function(b) actionHot:to(b and 1 or 0) end, click = o.Action })
	end
	local function paint()
		local a = scope.alpha
		fill.BackgroundColor3, fill.BackgroundTransparency = T.FrameInactive, 1 - (0.45 + 0.35 * hot.v) * a
		line.Color = T.PopupBorder:Lerp(Accent, on.v)
		line.Transparency = 1 - (0.55 + 0.45 * on.v) * a
		setText(name, tr(text), 12)
		name.TextColor3 = T.Text
		name.TextTransparency = 1 - (0.85 + 0.15 * max(hot.v, on.v)) * a
		if glyph then glyph:paint(T.Text, (0.85 + 0.15 * max(hot.v, on.v)) * a) end
	end
	hot.cb, on.cb = paint, paint
	scope:paint(paint)
	Hit(scope, row, { hover = function(b) hot:to(b and 1 or 0) end, click = o.Callback })
	self.y += 36 + self.spacing
	local object = {}
	function object:Select(state) on:to(state and 1 or 0) end
	return object
end

--[[ ---------------------------------------- Window ---------------------------------------- ]]

local function scaleGuiTreeX(root, factor)
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			local position, size = child.Position, child.Size
			child.Position = UDim2.new(position.X.Scale, position.X.Offset * factor, position.Y.Scale, position.Y.Offset)
			child.Size = UDim2.new(size.X.Scale, size.X.Offset * factor, size.Y.Scale, size.Y.Offset)
			scaleGuiTreeX(child, factor)
		end
	end
end

local WindowMeta = {}
WindowMeta.__index = WindowMeta

function WindowMeta:pos() return self.position end

function WindowMeta:dragTo(target)
	self.dragTarget = target
	if self.moving then return end
	self.moving = true
	Run(function(dt)
		self.position = self.position:Lerp(self.dragTarget, 1 - exp(-20 * dt))
		if (self.dragTarget - self.position).Magnitude < 0.5 then self.position = self.dragTarget end
		setXY(self.frame, round(self.position.X), round(self.position.Y))
		self.scope:invalidateGrid(true)
		if self.position == self.dragTarget then
			self.moving = false
			return false
		end
		return true
	end, self.scope)
end

function WindowMeta:Group(name)
	self.groupFirst = self.groupFirst == nil
	local label = Label(self.sideInner, "", 10, 0, 11, FontSemi)
	local scope = self.sideScope
	scope:paint(function()
		setText(label, tr(name), 11, FontSemi)
		label.TextColor3, label.TextTransparency = T.Title, 1 - 0.5 * scope.alpha
	end)
	table.insert(self.sideItems, { kind = "group", frame = label, first = self.groupFirst })
end

function WindowMeta:selectTab(tab, instantly)
	if self.current == tab then return end
	local previous = self.current
	self.current = tab
	if previous then
		previous.page.Visible = false
		previous.scope.inert = true
	end
	flushLazy(tab.page)
	tab.page.Visible = true
	tab.scope.inert = false
	local parent = tab.parentTab
	self:setExpanded(tab.expandedOwner or (parent) or (tab.children and tab) or nil)
	for _, t in self.tabs do t:paintActive() end
	if instantly then self.pageAnim:set(1) else self.pageAnim:set(0); self.pageAnim:to(1) end
end

function WindowMeta:setExpanded(owner)
	if self.expanded == owner then return end
	if self.expanded then self.expanded.expandAnim:to(0) end
	self.expanded = owner
	if owner then owner.expandAnim:to(1) end
end

function WindowMeta:relayoutSide()
	local y = 0
	for _, item in self.sideItems do
		if item.kind == "group" then
			if not item.first then y += 12 end
			setXY(item.frame, 10, y + 1)
			y = floor(y + 12.5 + 4)
		elseif item.kind == "tab" then
			if item.tab.parentTab then
				local parent = item.tab.parentTab
				local v = parent.expandAnim.v
				local full = #parent.children * 34
				item.tab.row.Visible = v > 0.01
				item.tab.rowScope.own = v
				item.tab.rowScope:refresh()
				setXY(item.tab.row, 0, (item.subIndex - 1) * 34)
				if item.subIndex == #parent.children then
					setWH(parent.subClip, 150, round(full * v))
					y = parent.subBase + full * v
				end
			else
				setXY(item.tab.row, 0, y)
				if item.tab.children then
					item.tab.subBase = y + 34
					setXY(item.tab.subClip, 0, item.tab.subBase)
				end
				y = y + 34
			end
		end
		self.sideScope:invalidateGrid(true)
	end
end

function WindowMeta:Tab(o)
	local win = self
	local parentTab = o.Parent
	local tab = setmetatable({ win = win, name = o.Name, boxes = {}, parentTab = parentTab }, TabMeta)
	local host = parentTab and parentTab.subClip or self.sideInner
	local row = Box(host, 0, 0, 150, 30)
	local indent = parentTab and 10 or 0
	local scope = newScope(self.sideScope)
	local pill = Box(row, 6 + indent, 0, 138 - indent, 30, T.TabActive, 6)
	local glyph = Glyph(row, o.Icon, 14)
	glyph:center(6 + indent + 9 + 8, 15)
	local label = ScrollText(row, 6 + indent + 32, 0, 138 - indent - 32 - 8, 30, 12, nil, scope)
	local active, hover = Anim(0, 4.85), Anim(0, 4.85)
	local function paint()
		local a = scope.alpha
		pill.BackgroundColor3 = T.TabActive
		pill.BackgroundTransparency = 1 - sat(active.v + hover.v * 0.4) * a
		local icon = T.Disabled
		if hover.v > 0 then icon = icon:Lerp(T.Text, hover.v) end
		if active.v > 0 then icon = icon:Lerp(Accent, active.v) end
		glyph:paint(icon, a)
		label:set(tr(o.Name))
		label:paint(T.Disabled:Lerp(T.Text, sat(active.v + hover.v)), a)
	end
	active.cb, hover.cb = paint, paint
	scope:paint(paint)
	tab.row, tab.rowScope = row, scope
	function tab:paintActive()
		local on = win.current == tab or (tab.children and win.current and win.current.parentTab == tab)
		active:to(on and 1 or 0)
	end
	Hit(scope, row, {
		hover = function(b) hover:to(b and 1 or 0); label:hover(b) end,
		click = function()
			if tab.children then
				local cur = win.current
				if not (cur and cur.parentTab == tab) then
					win:selectTab(tab.children[1])
				else
					win:setExpanded(tab)
				end
			else
				win:selectTab(tab)
			end
		end,
	})
	local pageWidth, pageHeight = win.width - 200, win.height - 91
	local page = Box(self.pages, 0, 0, pageWidth, pageHeight)
	page.ClipsDescendants = true
	page.Visible = false
	LazyRoots[page] = {}
	local content = Box(page, 0, 0, pageWidth, pageHeight)
	tab.page, tab.content, tab.scrollY, tab.scrollMax = page, content, 0, 0
	tab.pageScope = newScope(self.pagesScope)
	tab.pageScope.clip = page
	tab.pageScope.inert = true
	Wheel(tab.pageScope, page, function(z)
		tab.scrollY = clamp(tab.scrollY - z * 75, 0, tab.scrollMax)
		setXY(tab.content, 0, -tab.scrollY)
		for _, box in tab.boxes do box.scope:invalidateGrid(true) end
	end)
	tab.scope = tab.pageScope
	local entry = { kind = "tab", tab = tab }
	table.insert(self.tabs, tab)
	if parentTab then
		-- sub-tabs live in their parent's clip; relayout handles position and fade
		parentTab.children = parentTab.children or {}
		table.insert(parentTab.children, tab)
		entry.subIndex = #parentTab.children
	else
		function tab:EnableChildren()
			tab.expandAnim = Anim(0, 12, function() win:relayoutSide() end, 0.01)
			tab.subClip = Box(win.sideInner, 0, 0, 150, 0)
			tab.subClip.ClipsDescendants = true
			return tab
		end
	end
	table.insert(self.sideItems, entry)
	if not self.current and not parentTab then self:selectTab(tab, true) end
	return tab
end

function WindowMeta:Finish()
	for _, tab in self.tabs do tab:layout() end
	self:relayoutSide()
	for _, tab in self.tabs do tab:paintActive() end
	self.configs.init()
	self.scope:refresh()
	return self
end

-- Puts a value that is not a control into configs.
function WindowMeta:Flag(id, get, set)
	self.store.controls[id] = { get = get, set = set }
	local waiting = self.store.pending[id]
	if waiting ~= nil then
		self.store.pending[id] = nil
		set(waiting)
	end
end

function WindowMeta:Get(id)
	local control = self.store.controls[id]
	if control then return control.get() end
	return self.store.pending[id]
end

function WindowMeta:RegisterAction(name, callback)
	assert(type(name) == "string" and name ~= "", "Action name must be a non-empty string")
	assert(type(callback) == "function", "Action callback must be a function")
	local entry = { kind = "action", label = name, tabName = "Actions", box = "", action = callback, scope = self.scope }
	table.insert(self.searchIndex, entry)
	local removed = false
	return function()
		if removed then return end
		removed = true
		local index = table.find(self.searchIndex, entry)
		if index then table.remove(self.searchIndex, index) end
	end
end

local function settingsChanged()
	if CurrentWindow then CurrentWindow.queueSettings() end
end

function Library:SetTheme(name)
	if not Palettes[name] then return end
	Library.Theme = name
	repaintAll()
	settingsChanged()
end

function Library:SetAccent(color)
	Accent = color
	repaintAll()
	settingsChanged()
end

function Library:SetLanguage(index)
	Library.Language = index
	if CurrentWindow and CurrentWindow.onLanguage then CurrentWindow.onLanguage() end
	repaintAll()
	settingsChanged()
end

function Library:SetScale(scale)
	setRasterScale(scale)
	repaintAll()
	settingsChanged()
end

function Library:SetReducedMotion(enabled)
	assert(type(enabled) == "boolean", "ReducedMotion must be a boolean")
	ReducedMotion, Library.ReducedMotion = enabled, enabled
	if enabled then
		local active = {}
		for animation in Moving do table.insert(active, animation) end
		for animation in Queue do table.insert(active, animation) end
		for _, animation in active do animation:set(animation.t) end
	end
	repaintAll()
	settingsChanged()
end

local function readWindowSize(value, fallback, name)
	if value == nil then return fallback end
	local x, y
	if typeof(value) == "Vector2" then
		x, y = value.X, value.Y
	elseif type(value) == "table" then
		x, y = value.X or value[1], value.Y or value[2]
	else
		error(name .. " must be a Vector2 or { width, height }")
	end
	assert(type(x) == "number" and x > 0 and x < huge and type(y) == "number" and y > 0 and y < huge, name .. " dimensions must be finite and positive")
	return Vector2.new(x, y)
end

local function buildSearch(win, top)
	local scope, parent = win.topScope, win.frame
	local rightX, baseY = win.width - 15, 15
	local plate = Box(parent, rightX - 30, baseY, 30, 30, T.FrameInactive, 6)
	local iconHit = Box(parent, rightX - 30, baseY, 30, 30)
	local mag = Glyph(parent, "SEARCH", 14)
	mag:center(rightX - 15, baseY + 15)
	local input = New("TextBox", {
		Text = "", PlaceholderText = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12, Visible = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ClipsDescendants = true,
	}, parent)
	local placeholder = Label(parent, "", 0, 0, 12)
	placeholder.Visible = false
	local isOpen, hovered, hotA, openA = false, false, nil, nil
	local results
	local listFrame, listScope, listRows = nil, nil, {}
	local listA = 0
	local sel = 1
	local hits = {}
	local function paint()
		local a, o, h = scope.alpha, openA.v, hotA.v
		local e = o * o * (3 - 2 * o)
		local width = 30 + (250 - 30) * e
		setXY(plate, round(rightX - width), baseY)
		setWH(plate, round(width), 30)
		plate.BackgroundColor3, plate.BackgroundTransparency = T.FrameInactive, 1 - (0.5 + 0.3 * max(h, e)) * a
		mag:paint(T.Disabled:Lerp(T.Text, max(h, e)), a)
		local textX = round(rightX - width + 12)
		local textW = max(1, rightX - 30 + 4 - textX)
		input.Visible = e > 0.01
		placeholder.Visible = e > 0.01 and input.Text == ""
		setXY(input, textX, capY(baseY + 15, 12))
		setWH(input, textW, 16)
		setXY(placeholder, textX, capY(baseY + 15, 12))
		input.TextColor3, input.TextTransparency = T.Text, 1 - e * a
		setText(placeholder, tr("Search functions..."), 12)
		placeholder.TextColor3, placeholder.TextTransparency = T.Disabled, 1 - 0.75 * e * a
	end
	hotA, openA = Anim(0, 15, paint), Anim(0, 16, paint)
	scope:paint(paint)

	local rowW, rowH = 238, 32
	local function ensureList()
		if listFrame then return end
		local card = newCard({ width = 250, rounding = 12, name = "SearchList" })
		card.frame.Active = true
		listFrame, listScope = card, card.scope
		table.insert(Windows, { frame = card.frame, scope = card.scope })
		for i = 1, 8 do
			local row = Box(card.content, 6, 6 + (i - 1) * rowH, rowW, rowH)
			local bg = Box(row, 0, 0, rowW, rowH, T.FrameInactive, 6)
			local labelClip = Box(row, 0, 0, rowW, rowH)
			labelClip.ClipsDescendants = true
			local a = Label(labelClip, "", 10, capY(16, 12), 12)
			local b = Label(labelClip, "", 0, capY(16, 12), 12)
			local m = Label(labelClip, "", 0, capY(16, 12), 12)
			local path = New("TextLabel", {
				Text = "", BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12, Size = UDim2.fromOffset(150, 16),
				Position = UDim2.fromOffset(rowW - 10 - 150, capY(16, 12)), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top,
			}, row)
			local t = Anim(0, 15)
			local rowObj = { row = row }
			local function paintRow()
				local alpha = card.scope.alpha
				bg.BackgroundColor3, bg.BackgroundTransparency = T.FrameInactive, 1 - 0.8 * t.v * alpha
				a.TextColor3, a.TextTransparency = T.Text, 1 - alpha
				m.TextColor3, m.TextTransparency = Accent, 1 - alpha
				b.TextColor3, b.TextTransparency = T.Text, 1 - alpha
				path.TextColor3, path.TextTransparency = T.Disabled, 1 - 0.9 * alpha
			end
			t.cb = paintRow
			card.scope:paint(paintRow)
			rowObj.fill = function(entry, startAt, needleLen)
				local shown = tr(entry.label)
				local first = utf8.offset(shown, startAt or (utf8.len(shown) + 1)) or (#shown + 1)
				local after = utf8.offset(shown, (startAt or 0) + needleLen) or (#shown + 1)
				local part1, part2, part3 = string.sub(shown, 1, first - 1), string.sub(shown, first, after - 1), string.sub(shown, after)
				setText(a, part1, 12)
				setText(m, part2, 12)
				setText(b, part3, 12)
				local w1 = part1 ~= "" and measure(part1, 12) or 0
				setXY(m, round(10 + w1), capY(16, 12))
				setXY(b, round(10 + w1 + (part2 ~= "" and measure(part2, 12) or 0)), capY(16, 12))
				path.Text = tr(entry.tabName) .. "   " .. tr(entry.box or "")
				setWH(labelClip, max(1, rowW - 10 - measure(path.Text, 12) - 6), rowH)
				rowObj.entry = entry
			end
			rowObj.t = t
			Hit(card.scope, row, {
				hover = function(state)
					if state then
						sel = i
						for k, r in listRows do r.t:to(k == sel and 1 or 0) end
					end
				end,
				click = function() if rowObj.entry then results(rowObj.entry) end end,
			})
			listRows[i] = rowObj
		end
		local empty = Label(card.content, "", 16, capY(22, 12), 12)
		empty.Visible = false
		card.scope:paint(function()
			setText(empty, tr("No matching functions"), 12)
			empty.TextColor3, empty.TextTransparency = T.Disabled, 1 - card.scope.alpha
		end)
		card.empty = empty
	end
	local function setList(show)
		ensureList()
		local card = listFrame
		card.frame.ZIndex = 50000
		if show then
			card.frame.Visible = true
			local a = toStage(parent.AbsolutePosition)
			card.base = Vector2.new(a.X + rightX - 250, a.Y + baseY + 30 + 8)
			card:apply()
			card.isOpen = true
		else
			card.isOpen = false
		end
		card:startFade()
	end
	local function refreshHits()
		local q = normalizeSearch(input.Text)
		table.clear(hits)
		if q ~= "" then
			for order, entry in win.searchIndex do
				if not string.match(entry.label, "^%d+$") then
					if entry.normalizedLanguage ~= Library.Language then
						entry.normalized = normalizeSearch(tr(entry.label))
						entry.normalizedLanguage = Library.Language
					end
					local at = string.find(entry.normalized, q, 1, true)
					if at then
						local previous = at > 1 and string.byte(entry.normalized, at - 1)
						local boundary = previous == nil or previous == 32 or previous == 45 or previous == 46 or previous == 47 or previous == 58 or previous == 95
						local rank = entry.normalized == q and 0 or (at == 1 and 1 or (boundary and 2 or 3))
						local candidate = { entry, utf8.len(entry.normalized, 1, at), rank, at, order }
						local insertAt = 1
						while insertAt <= #hits do
							local current = hits[insertAt]
							if rank < current[3]
								or (rank == current[3] and at < current[4])
								or (rank == current[3] and at == current[4] and order < current[5]) then
								break
							end
							insertAt += 1
						end
						if insertAt <= 8 then
							table.insert(hits, insertAt, candidate)
							if #hits > 8 then table.remove(hits) end
						end
					end
				end
			end
		end
		local queryLength = utf8.len(q)
		sel = clamp(sel, 1, max(1, #hits))
		ensureList()
		for i, row in listRows do
			local hit = hits[i]
			row.row.Visible = hit ~= nil
			if hit then row.fill(hit[1], hit[2], queryLength) end
			row.t:to(i == sel and 1 or 0)
		end
		listFrame.empty.Visible = #hits == 0
		listFrame:setHeight(12 + max(1, #hits) * rowH)
		setList(isOpen and q ~= "" and input:IsFocused())
	end
	local function setOpen(state)
		isOpen = state
		openA:to(state and 1 or 0)
		if state then
			input.Visible = true
			input:CaptureFocus()
		else
			input.Text = ""
			input:ReleaseFocus()
			setList(false)
		end
	end
	results = function(entry)
		if entry.action then
			setOpen(false)
			entry.action()
			return
		end
		win:selectTab(entry.tab)
		local tabObj = entry.tab
		if tabObj and tabObj.parentTab then win:setExpanded(tabObj.parentTab) end
		setOpen(false)
		entry.flash = 1.2
		Run(function(dt)
			entry.flash = max(0, entry.flash - dt)
			if entry.paint then entry.paint() end
			return entry.flash > 0
		end, entry.scope)
	end
	connect(input:GetPropertyChangedSignal("Text"), function()
		placeholder.Visible = input.Visible and input.Text == ""
		if isOpen then refreshHits() end
	end, scope)
	connect(input.FocusLost, function(enter)
		if enter and hits[sel] then
			results(hits[sel][1])
			return
		end
		if listFrame and listFrame.frame.Visible and inside(listFrame.frame, mouseAbs()) then return end
		if input.Text == "" and isOpen and not hovered then setOpen(false) else setList(false) end
	end, scope)
	Hit(scope, iconHit, {
		hover = function(b) hovered = b; hotA:to(b and 1 or 0) end,
		click = function() setOpen(not isOpen) end,
	})
	Hit(scope, input, {})
	connect(UserInputService.InputBegan, function(input2, processed)
		if processed or not win.frame.Visible then return end
		if input2.KeyCode == Enum.KeyCode.K
			and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
			and not UserInputService:GetFocusedTextBox() then
			setOpen(not isOpen)
			return
		end
		if not isOpen then return end
		if input2.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		elseif #hits > 0 and (input2.KeyCode == Enum.KeyCode.Down or input2.KeyCode == Enum.KeyCode.Up) then
			local count = #hits
			sel = input2.KeyCode == Enum.KeyCode.Down and sel % count + 1 or (sel - 2) % count + 1
			for k, r in listRows do r.t:to(k == sel and 1 or 0) end
		end
	end, scope)
	win.search = { setOpen = setOpen }
	win.relayoutSearch = function()
		rightX = win.width - 15
		paint()
		if listFrame and listFrame.frame.Visible then
			local a = toStage(parent.AbsolutePosition)
			listFrame.base = Vector2.new(a.X + rightX - 250, a.Y + baseY + 30 + 8)
			listFrame:apply()
		end
	end
	table.insert(win.resizeCallbacks, win.relayoutSearch)
end

-- Presets on disk. One JSON file per preset; `selected` is the one loaded right now.
local function newConfigs(win, onChanged)
	local store = win.store
	local configDir, trashDir = win.folder .. "/configs", win.folder .. "/trash"
	local M = { list = {}, trash = {}, selected = 1 }
	local sequence = 0

	local function stamp()
		sequence += 1
		return os.time() + sequence / 1000
	end
	local function pathFor(dir, name) return dir .. "/" .. safeName(name) .. ".json" end
	local function snapshot()
		local values = {}
		for id, value in store.pending do values[id] = value end
		for id, control in store.controls do values[id] = control.get() end
		return values
	end
	local function apply(values)
		if type(values) ~= "table" then return end
		for id, value in values do
			local control = store.controls[id]
			if control then control.set(value) else store.pending[id] = value end
		end
	end
	local function writeConfig(dir, cfg, values)
		Files.write(pathFor(dir, cfg.name), encodeJSON({ name = cfg.name, created = cfg.created, modified = cfg.modified, values = values }))
	end
	local function readValues(dir, cfg)
		local data = decodeJSON(Files.read(pathFor(dir, cfg.name)))
		return type(data) == "table" and data.values or {}
	end
	local function unique(list, name, except)
		local function taken(candidate)
			local key = string.lower(safeName(candidate))
			for _, cfg in list do
				if cfg ~= except and string.lower(safeName(cfg.name)) == key then return true end
			end
			return false
		end
		if not taken(name) then return name end
		local n = 2
		while taken(name .. " " .. n) do n += 1 end
		return name .. " " .. n
	end
	local function scan(dir, into)
		table.clear(into)
		for _, file in Files.list(dir) do
			if string.sub(file, -5) == ".json" then
				local data = decodeJSON(Files.read(dir .. "/" .. file))
				if type(data) == "table" then
					table.insert(into, { name = data.name or string.sub(file, 1, -6), created = tonumber(data.created) or 0, modified = tonumber(data.modified) or 0 })
				end
			end
		end
	end

	function M.current() return M.list[M.selected] end

	function M.create(name)
		local time = stamp()
		local cfg = { name = unique(M.list, name), created = time, modified = time }
		table.insert(M.list, cfg)
		writeConfig(configDir, cfg, snapshot())
		return #M.list
	end

	function M.save(i)
		local cfg = M.list[i]
		cfg.modified = stamp()
		writeConfig(configDir, cfg, snapshot())
	end

	function M.load(i)
		M.selected = i
		apply(readValues(configDir, M.list[i]))
		win.queueSettings()
	end

	function M.rename(i, name)
		local cfg = M.list[i]
		local values = readValues(configDir, cfg)
		Files.delete(pathFor(configDir, cfg.name))
		cfg.name = unique(M.list, name, cfg)
		cfg.modified = stamp()
		writeConfig(configDir, cfg, values)
		win.queueSettings()
	end

	function M.duplicate(i)
		local source = M.list[i]
		local time = stamp()
		local copy = { name = unique(M.list, source.name), created = time, modified = time }
		writeConfig(configDir, copy, readValues(configDir, source))
		table.insert(M.list, i + 1, copy)
		if M.selected > i then M.selected += 1 end
		return copy
	end

	function M.remove(i)
		local cfg = table.remove(M.list, i)
		local values = readValues(configDir, cfg)
		Files.delete(pathFor(configDir, cfg.name))
		cfg.name = unique(M.trash, cfg.name)
		writeConfig(trashDir, cfg, values)
		table.insert(M.trash, cfg)
		if #M.list == 0 then M.create("Default") end
		if M.selected > i or M.selected > #M.list then M.selected = max(1, M.selected - 1) end
		win.queueSettings()
		return cfg
	end

	function M.restore(j)
		local cfg = table.remove(M.trash, j)
		local values = readValues(trashDir, cfg)
		Files.delete(pathFor(trashDir, cfg.name))
		cfg.name = unique(M.list, cfg.name)
		cfg.modified = stamp()
		writeConfig(configDir, cfg, values)
		table.insert(M.list, cfg)
		return cfg
	end

	function M.purge(j)
		local cfg = table.remove(M.trash, j)
		Files.delete(pathFor(trashDir, cfg.name))
	end

	-- Hands the preset's file to the clipboard, where the executor provides one.
	function M.export(i)
		if type(setclipboard) ~= "function" then return false end
		return (pcall(setclipboard, Files.read(pathFor(configDir, M.list[i].name)) or ""))
	end

	function M.init()
		Files.folder(configDir)
		Files.folder(trashDir)
		scan(configDir, M.list)
		scan(trashDir, M.trash)
		if #M.list == 0 then M.create("Default") end
		M.selected = 1
		for i, cfg in M.list do
			if cfg.name == win.saved.lastConfig then M.selected = i end
		end
		apply(readValues(configDir, M.current()))
		onChanged()
	end

	return M
end

local function buildConfigPopup(win, configs, onChanged)
	local sortMode = 1
	local searchText = ""
	local card, rowsScope, searchInput
	local rebuild, rowMenu, sortMenu, binMenu, menuRow
	local listClip, listInner, listScroll, autoSaveHolder, autoSaveFlow
	local listY, width, inner, rowH, rowGap = 90, 340, 320, 36, 8

	local function notify(title, text, ...)
		pushNotification(tr(title), string.format(tr(text), ...))
	end
	local function copied(i)
		if configs.export(i) then
			notify("Share", "Copied %s to the clipboard", configs.list[i].name)
		else
			pushNotification(tr("Share"), tr("Clipboard is not available"))
		end
	end
	local function order()
		local out = {}
		local needle = string.lower(searchText)
		for i, cfg in configs.list do
			if needle == "" or string.find(string.lower(cfg.name), needle, 1, true) then table.insert(out, i) end
		end
		table.sort(out, function(a, b)
			local x, y = configs.list[a], configs.list[b]
			if sortMode == 2 then return x.modified > y.modified end
			if sortMode == 3 then return string.lower(x.name) < string.lower(y.name) end
			return x.created > y.created
		end)
		return out
	end
	local function pick(i)
		if i == configs.selected then return end
		configs.load(i)
		notify("Config Loaded", "Loaded config: %s", configs.list[i].name)
		rebuild()
		onChanged()
	end

	local pool = {}
	local emptyLabel = nil
	local autoSave = false
	local autoSaveTimer = 0

	local function ensurePool()
		if #pool > 0 then return end
		rowsScope = newScope(card.scope)
		rowsScope.clip = listClip
		emptyLabel = Label(listInner, "", 0, capY(rowH * 0.5, 12), 12)
		emptyLabel.Text = tr("No presets found")
		setWH(emptyLabel, inner, 16)
		emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
		emptyLabel.Visible = false
		rowsScope:paint(function() emptyLabel.TextColor3, emptyLabel.TextTransparency = T.Disabled, 1 - rowsScope.alpha end)

		for slot = 1, 8 do
			local rowFrame = Box(listInner, 0, 0, inner, rowH)
			rowFrame.ClipsDescendants = true
			rowFrame.Visible = false
			local fill = Box(rowFrame, 0, 0, inner, rowH, T.FrameInactive, 8)
			local tint = Box(rowFrame, 0, 0, inner, rowH, Accent, 8)
			local line = Stroke(Box(rowFrame, 1, 1, inner - 2, rowH - 2, nil, 7), Accent)
			local nameLabel = Label(rowFrame, "", 12, capY(rowH * 0.5, 12), 12)
			nameLabel.Size = UDim2.fromOffset(inner - 84, 16)
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			local hov = Anim(0, 15)
			local itemData = {
				frame = rowFrame, fill = fill, tint = tint, line = line,
				nameLabel = nameLabel, hov = hov, cfgIndex = nil, isSelected = false,
			}
			local function paintRow()
				local a = rowsScope.alpha
				local isSel = itemData.isSelected
				fill.BackgroundColor3, fill.BackgroundTransparency = T.FrameInactive, 1 - (0.45 + 0.4 * hov.v) * a
				tint.BackgroundColor3, tint.BackgroundTransparency = Accent, isSel and 1 - 0.1 * a or 1
				line.Color = isSel and Accent or T.PopupBorder
				line.Transparency = 1 - (isSel and 1 or 0.5) * a
				nameLabel.TextColor3 = T.Text
				nameLabel.TextTransparency = 1 - ((isSel and 1 or 0.85) + (isSel and 0 or 0.15) * hov.v) * a
			end
			hov.cb = paintRow
			rowsScope:paint(paintRow)

			local actX = inner - 10 - 26
			local menuX = actX - 26 - 2
			IconButton(rowFrame, rowsScope, "ELLIPSIS_H", menuX, 0, 26, rowH, DimHot, function()
				if itemData.cfgIndex then
					menuRow = itemData.cfgIndex
					rowMenu:open(1, mouseAbs())
				end
			end)
			local actBtn = IconButton(rowFrame, rowsScope, "SAVE", actX, 0, 26, rowH, DimHot, function()
				local ci = itemData.cfgIndex
				if not ci or not configs.list[ci] then return end
				if ci == configs.selected then
					configs.save(ci)
					notify("Config Saved", "Saved changes to %s", configs.list[ci].name)
				else
					pick(ci)
				end
			end)
			itemData.actBtn = actBtn

			local lastClick = 0
			Hit(rowsScope, rowFrame, {
				hover = function(b) hov:to((b or itemData.isSelected) and 1 or 0) end,
				click = function()
					local ci = itemData.cfgIndex
					if not ci or not configs.list[ci] then return end
					local cfg = configs.list[ci]
					local now = os.clock()
					if now - lastClick < 0.35 then
						local box = New("TextBox", {
							Text = cfg.name, ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12,
							TextColor3 = T.Text, Position = UDim2.fromOffset(12, capY(rowH * 0.5, 12)), Size = UDim2.fromOffset(menuX - 18, 16),
							TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5,
						}, rowFrame)
						nameLabel.Visible = false
						box:CaptureFocus()
						connect(box.FocusLost, function(enter)
							if enter and box.Text ~= "" and box.Text ~= cfg.name then
								local old = cfg.name
								configs.rename(ci, box.Text)
								notify("Config Renamed", "Renamed %s to %s", old, cfg.name)
							end
							box:Destroy()
							nameLabel.Visible = true
							rebuild()
							onChanged()
						end, rowsScope)
						return
					end
					lastClick = now
					pick(ci)
				end,
			})
			table.insert(pool, itemData)
		end
	end

	local function updateVisibleRows(list)
		emptyLabel.Visible = #list == 0
		local firstIdx = clamp(floor(listScroll.y / (rowH + rowGap)) + 1, 1, max(1, #list))
		for slot = 1, 8 do
			local r = pool[slot]
			local itemIdx = firstIdx + slot - 1
			if itemIdx <= #list then
				local cfgIdx = list[itemIdx]
				local cfg = configs.list[cfgIdx]
				local isSel = cfgIdx == configs.selected
				r.cfgIndex = cfgIdx
				r.isSelected = isSel
				setText(r.nameLabel, cfg.name, 12)
				setWH(r.nameLabel, inner - 84, 16)
				setXY(r.frame, 0, (itemIdx - 1) * (rowH + rowGap))
				r.frame.Visible = true
				r.hov:set(isSel and 1 or 0)
			else
				r.cfgIndex = nil
				r.frame.Visible = false
			end
		end
	end

	rebuild = function()
		if not card or not listClip then return end
		ensurePool()
		local list = order()
		local rows = max(1, #list)
		local listH = min(rows, 7) * (rowH + rowGap) - rowGap
		setWH(listClip, inner, listH)
		setWH(listInner, inner, rows * (rowH + rowGap) - rowGap)
		listScroll.max = max(0, rows * (rowH + rowGap) - rowGap - listH)
		listScroll.y = clamp(listScroll.y, 0, listScroll.max)
		setXY(listInner, 0, -listScroll.y)
		if autoSaveHolder then
			local autoSaveY = 10 + listY + listH + 10
			setXY(autoSaveHolder, 10, autoSaveY)
			card:setHeight(autoSaveY + (autoSaveFlow and autoSaveFlow:bottom() or 0) + 10)
		end
		updateVisibleRows(list)
		rowsScope:refresh()
	end

	local function miniCard(w, build, offX, offY)
		return newCard({
			width = w, name = "CfgMenu", build = build,
			place = function(self2, point)
				local at = toStage(point or mouseAbs())
				local a = win:pos()
				local maxX = max(a.X + 10, a.X + win.width - w - 10)
				local maxY = max(a.Y + 10, a.Y + win.height - self2.height - 10)
				return Vector2.new(clamp(at.X + offX, a.X + 10, maxX), clamp(at.Y + offY, a.Y + 10, maxY))
			end,
		})
	end
	local function red()
		local color = Color3.new(.898, .286, .29)
		return color, color
	end

	rowMenu = miniCard(152, function(c)
		MenuRow(c, 10, 132, "SHARE", "Share", DimHot, function()
			if configs.list[menuRow] then copied(menuRow) end
			closePopupsTo(1)
		end)
		MenuRow(c, 43, 132, "COPY", "Duplicate", DimHot, function()
			if configs.list[menuRow] then
				local copy = configs.duplicate(menuRow)
				notify("Config Duplicated", "Duplicated %s", copy.name)
				rebuild()
			end
			closePopupsTo(1)
		end)
		MenuRow(c, 76, 132, "TRASH", "Delete", red, function()
			if configs.list[menuRow] then
				local gone = configs.remove(menuRow)
				notify("Config Deleted", "Removed config: %s", gone.name)
				rebuild()
				onChanged()
			end
			closePopupsTo(1)
		end)
		c:setHeight(20 + 33 * 3)
	end, 8, 14)

	local sortOptions = { "Newest First", "Recently Modified", "Alphabetical" }
	local sortW = choiceWidth(sortOptions)
	sortMenu = miniCard(sortW, function(c)
		local rows
		rows = choiceRows(c, sortW - 20, sortOptions, function(i) return i == sortMode end, function(i)
			sortMode = i
			for _, r in rows do r() end
			rebuild()
		end, 10)
		c:setHeight(20 + 3 * 33)
	end, -(sortW - 28), 24)

	local binScope, binRebuild
	binMenu = miniCard(216, function(c)
		local holder = Box(c.content, 10, 10, 196, 33)
		binRebuild = function()
			if binScope then
				local index = table.find(c.scope.kids, binScope)
				if index then table.remove(c.scope.kids, index) end
			end
			binScope = newScope(c.scope)
			for _, child in holder:GetChildren() do child:Destroy() end
			if #configs.trash == 0 then
				local empty = New("TextLabel", {
					Text = tr("Bin is empty"), BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12, Size = UDim2.fromOffset(196, 16),
					Position = UDim2.fromOffset(0, capY(16.5, 12)), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
				}, holder)
				binScope:paint(function() empty.TextColor3, empty.TextTransparency = T.Disabled, 1 - binScope.alpha end)
			end
			for i, cfg in configs.trash do
				local y = (i - 1) * 33
				local name = Label(holder, cfg.name, 2, y + capY(16.5, 12), 12)
				binScope:paint(function() name.TextColor3, name.TextTransparency = T.Text, 1 - binScope.alpha end)
				IconButton(holder, binScope, "TRASH", 196 - 52 - 6, y, 26, 33, red, function()
					configs.purge(i)
					binRebuild()
				end)
				IconButton(holder, binScope, "UNDO", 196 - 26, y, 26, 33, DimHot, function()
					local back = configs.restore(i)
					notify("Config Restored", "Restored %s", back.name)
					binRebuild()
					rebuild()
				end)
			end
			local n = max(1, #configs.trash)
			setWH(holder, 196, n * 33)
			c:setHeight(20 + n * 33)
			binScope:refresh()
		end
		binRebuild()
	end, -110, 24)
	binMenu.onOpen = function() if binRebuild then binRebuild() end end

	local function ensure()
		if card then return card end
		card = newCard({
			width = width, name = "Presets",
			place = function()
				local a = win:pos()
				return keepOnScreen(card, a.X + 190 + 35, a.Y + 15 + 36, 10)
			end,
			build = function(c)
				local content, scope = c.content, c.scope
				local o = 10
				local iconW = glyphContours("CLOUD").adv / 512 * 14
				local badgeW = 12 + iconW + 7 + measure(tr("Presets"), 14, FontSemi) + 12
				local badge = Box(content, o, o, round(badgeW), 30, Accent, 8)
				local cloud = Glyph(badge, "CLOUD", 14)
				cloud:center(12 + iconW * 0.5, 15)
				local title = Label(badge, "", round(12 + iconW + 7), capY(15, 14), 14, FontSemi)
				scope:paint(function()
					badge.BackgroundColor3, badge.BackgroundTransparency = Accent, 1 - scope.alpha
					cloud:paint(White, scope.alpha)
					setText(title, tr("Presets"), 14, FontSemi)
					title.TextColor3, title.TextTransparency = White, 1 - scope.alpha
				end)
				local top = o + 1
				local x = o + inner - 28
				IconButton(content, scope, "PLUS", x, top, 28, 28, DimHot, function()
					configs.selected = configs.create("Unnamed")
					win.queueSettings()
					pushNotification(tr("Config Created"), tr("Created new config"))
					rebuild()
					onChanged()
				end)
				x -= 34
				IconButton(content, scope, "TRASH_RESTORE", x, top, 28, 28, DimHot, function() binMenu:open(1, mouseAbs()) end)
				x -= 34
				IconButton(content, scope, "CLOUD_UPLOAD_ALT", x, top, 28, 28, function() return Accent, T.Text end, function()
					if configs.current() then copied(configs.selected) end
				end)

				local searchY = o + 30 + 14
				local fieldW = inner - 34 - 8
				local field = Box(content, o, searchY, fieldW, 34, T.FrameInactive, 8)
				local fieldLine = Stroke(Box(field, 1, 1, fieldW - 2, 32, nil, 7), T.PopupBorder)
				local mag = Glyph(field, "SEARCH", 14)
				mag:center(12 + mag.boxW * 0.5, 17)
				local textX = round(12 + mag.boxW + 10)
				searchInput = New("TextBox", {
					Text = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = FontMedium, TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(textX, capY(17, 12)),
					Size = UDim2.fromOffset(fieldW - 12 - textX, 16), ClipsDescendants = true,
				}, field)
				local hint = Label(field, "", textX, capY(17, 12), 12)
				local sortBox = Box(content, o + inner - 34, searchY, 34, 34, T.FrameInactive, 8)
				local sortLine = Stroke(Box(sortBox, 1, 1, 32, 32, nil, 7), T.PopupBorder)
				IconButton(content, scope, "SORT_AMOUNT_DOWN", o + inner - 34, searchY, 34, 34, DimHot, function() sortMenu:open(1, mouseAbs()) end)
				scope:paint(function()
					local a = scope.alpha
					field.BackgroundColor3, field.BackgroundTransparency = T.FrameInactive, 1 - 0.85 * a
					sortBox.BackgroundColor3, sortBox.BackgroundTransparency = T.FrameInactive, 1 - 0.85 * a
					fieldLine.Color, fieldLine.Transparency = T.PopupBorder, 1 - 0.6 * a
					sortLine.Color, sortLine.Transparency = T.PopupBorder, 1 - 0.6 * a
					mag:paint(T.Disabled, a)
					searchInput.TextColor3, searchInput.TextTransparency = T.Text, 1 - a
					setText(hint, tr("Search"), 12)
					hint.TextColor3, hint.TextTransparency = T.Disabled, 1 - 0.75 * a
				end)
				connect(searchInput:GetPropertyChangedSignal("Text"), function()
					searchText = searchInput.Text
					hint.Visible = searchText == "" and not searchInput:IsFocused()
					rebuild()
				end, scope)
				Hit(scope, searchInput, {})
				connect(searchInput.Focused, function() hint.Visible = false end, scope)
				connect(searchInput.FocusLost, function() hint.Visible = searchInput.Text == "" end, scope)

				listClip = Box(content, o, o + listY, inner, 100)
				listClip.ClipsDescendants = true
				listInner = Box(listClip, 0, 0, inner, 100)
				listScroll = { y = 0, max = 0 }
				Wheel(scope, listClip, function(z)
					listScroll.y = clamp(listScroll.y - z * 75, 0, listScroll.max)
					setXY(listInner, 0, -listScroll.y)
					updateVisibleRows(order())
				end)

				-- Task 4.1: Auto-Save Config toggle
				autoSaveHolder = Box(content, o, o + listY + 10, inner, 33)
				autoSaveFlow = newFlow({
					parent = autoSaveHolder, scope = scope, x = 0, y = 0, w = inner, rw = inner,
					card = c, level = c.level, win = win,
				})
				local autoSaveCancel
				autoSaveFlow:PopupToggle("SAVE", "Auto-Save Config", false, function(state)
					autoSave = state
					if not state and autoSaveCancel then
						autoSaveCancel()
						autoSaveCancel = nil
					end
				end)

				if win.store then
					local prevOnChange = win.store.onChange
					local wrappedOnChange
					wrappedOnChange = function()
						if prevOnChange then prevOnChange() end
						if autoSave and configs.selected and configs.list[configs.selected] then
							autoSaveTimer = 0.5
							if autoSaveCancel then autoSaveCancel() end
							autoSaveCancel = Run(function(dt)
								autoSaveTimer -= dt
								if autoSaveTimer <= 0 then
									configs.save(configs.selected)
									autoSaveCancel = nil
									return false
								end
								return true
							end, scope)
						end
					end
					win.store.onChange = wrappedOnChange
					scope:onDestroy(function()
						if win.store.onChange == wrappedOnChange then win.store.onChange = prevOnChange end
						if autoSaveCancel then autoSaveCancel(); autoSaveCancel = nil end
					end)
				end
				rebuild()
			end,
		})
		return card
	end
	return function()
		local c = ensure()
		c:open(0)
		rebuild()
	end
end

local function buildUserCard(win, profile)
	local language, scales, units, safe = { "English", "Russian", "Turkish" }, { "75%", "100%", "125%", "150%", "175%", "200%" }, { "Auto", "Metric", "Imperial" }, { "Disabled", "Enabled" }
	local scaleValues = { .75, 1, 1.25, 1.5, 1.75, 2 }
	return newCard({
		width = 250, name = "UserCard",
		place = function(c)
			local a = win:pos()
			return keepOnScreen(c, a.X + 160 + 10, a.Y + 592 - c.height)
		end,
		build = function(c)
			local content, scope = c.content, c.scope
			Avatar.new(content, 14, 10, 40, scope)
			local name = Label(content, "", 66, 12, 12, FontSemi)
			local till = Label(content, "", 66, 26, 11)
			local renew = Label(content, "", 66, 39, 11)
			scope:paint(function()
				local a = scope.alpha
				setText(name, profile.name, 12, FontSemi)
				setText(till, tr(profile.status), 11)
				setText(renew, tr(profile.actionText or (profile.onAction and "Manage" or "")), 11)
				renew.Visible = profile.onAction ~= nil or profile.actionText ~= nil
				name.TextColor3, name.TextTransparency = T.Text, 1 - a
				till.TextColor3, till.TextTransparency = T.Disabled, 1 - a
				renew.TextColor3, renew.TextTransparency = Accent, 1 - a
			end)
			Hit(scope, renew, {
				click = function()
					if profile.onAction then profile.onAction(win, profile) end
				end,
			})
			local flow = newFlow({ parent = content, scope = scope, x = 10, y = 56, w = 230, rw = 230, card = c, level = c.level, win = win, path = "settings" })
			flow:Option("GLOBE", "Language", language, Library.Language + 1, function(_, i) Library:SetLanguage(i - 1) end)
			flow:Option("TEXT_HEIGHT", "Menu Scale", scales, table.find(scaleValues, Scale) or 2, function(_, i) Library:SetScale(scaleValues[i]) end)
			flow.store = win.settingsStore
			flow:Option("TEXT_SIZE", "ESP Scale", scales, 2)
			flow:Option("CLONE", "Windows Scale", scales, 2)
			flow:Option("RULER_TRIANGLE", "Units", units, 1)
			flow.store = nil

			-- Style: the cog opens the theme list, the swatch edits the accent colour.
			local accentValue = newColor(Accent, 1)
			local themeCard, accentCard
			local r = flow:rowImpl("FILL_DRIP", "Style", false, true)
			local swX, swY = r.W - 4 - 15, 9
			local previewBase, paintAccent = Preview(r.row, swX, swY, 15, 4, scope)
			local swHot, cogT = Anim(0, 15), Anim(0, 15)
			local swRing = Stroke(Box(r.row, swX - 1, swY - 1, 17, 17, nil, 5), White)
			local cog = Glyph(r.row, "COG", 14)
			cog:center(swX - 9 - cog.boxW * 0.5, 16.5)
			local cogHit = Box(r.row, round(swX - 13 - cog.boxW), 6, round(cog.boxW + 8), 21)
			r.setExtra(function()
				accentValue.a = Accent
				paintAccent(accentValue, scope.alpha)
				swRing.Transparency = 1 - 0.35 * swHot.v * scope.alpha
				cog:paint(T.Disabled:Lerp(T.Text, max(cogT.v, r.t.v * 0.6)), scope.alpha)
			end)
			swHot.cb, cogT.cb = r.paint, r.paint
			scope:paint(r.paint)
			local function openTheme()
				if not themeCard then
					themeCard = optionCard(flow, Library.ThemeNames, function() return table.find(Library.ThemeNames, Library.Theme) or 1 end, function(i)
						Library:SetTheme(Library.ThemeNames[i])
					end, r.top, function(state) r.setLit(state); cogT:to(state and 1 or 0) end)
				end
				themeCard:open(c.level)
			end
			Hit(scope, previewBase, {
				hover = function(b) swHot:to(b and 1 or 0) end,
				click = function()
					if not accentCard then
						accentCard = newCard({
							width = 274, padding = 16, name = "AccentCard",
							build = function(pc)
								local pf = newFlow({ parent = pc.content, scope = pc.scope, x = 16, y = 16, w = 242, rw = 240, card = pc, level = pc.level, win = win })
								local bottom = buildPicker(pf, { { name = "Accent", value = accentValue } }, false, function(col)
									Library:SetAccent(col.a)
								end)
								pc:setHeight(bottom + 16)
							end,
							place = function(pc)
								local at = toStage(previewBase.AbsolutePosition)
								return keepOnScreen(pc, at.X + 15 + 12, at.Y - 18)
							end,
						})
					end
					accentCard:open(c.level)
				end,
			})
			Hit(scope, cogHit, { hover = function(b) cogT:to(b and 1 or 0) end, click = openTheme })
			r.handlers.click = openTheme
			Hit(scope, r.row, r.handlers)

			flow:Separator()
			flow.store = win.settingsStore
			flow:Option("SHIELD_ALT", "Safe Mode", safe, 1)
			flow:PopupToggle("SYNC_ALT", "Synchronization", true)
			flow.store = nil
			flow:Separator()
			-- Task 3.2: HUD Overlay toggles
			flow:PopupToggle("AWARD", "Watermark", false, function(state) win:SetWatermark(state) end)
			flow:PopupToggle("LIST_ALT", "Keybind List", false, function(state) win:SetKeybindList(state) end)
			flow:PopupToggle("MUSIC", "Spotify", false, function(state) win.setSpotify(state) end)

			-- Task 3.4: Live Theme Creator
			local editThemeCard = nil
			flow:Row("PALETTE", "Edit Theme", function()
				if not editThemeCard then
					editThemeCard = newCard({
						width = 260, padding = 16, name = "EditThemeCard",
						build = function(tc)
							local tf = newFlow({ parent = tc.content, scope = tc.scope, x = 12, y = 14, w = 236, rw = 236, card = tc, level = tc.level, win = win })
							local themeName = "Custom"
							local editColors = { "Body", "Side", "Group", "Top", "FrameInactive", "Border", "Text" }
							for _, colName in editColors do
								local curCol = T[colName] or Color3.new(0.5, 0.5, 0.5)
								local sw = newColor(curCol, 1)
								tf:Color({ Name = colName, Color = sw, Callback = function(c)
									T[colName] = c.a
									applyPalette()
									Root:refresh()
								end })
							end
							tf:Separator()
							tf:Textbox({ Name = "Theme Name", Default = "Custom", Callback = function(t) themeName = t end })
							tf:Space(6)
							tf:Button({ Name = "Save Theme", Callback = function()
								if themeName and themeName ~= "" then
									local colors = {}
									for k, v in T do colors[k] = toHex(v) end
									Files.write(win.folder .. "/themes/" .. safeName(themeName) .. ".json", encodeJSON({ Colors = colors }))
									Palettes[themeName] = {}
									for k, v in T do Palettes[themeName][k] = { v, 1 } end
									if not table.find(Library.ThemeNames, themeName) then
										table.insert(Library.ThemeNames, themeName)
									end
									Library:SetTheme(themeName)
									pushNotification(tr("Style"), "Saved theme " .. themeName)
									tc:close()
								end
							end })
							tc:setHeight(tf:bottom() + 14)
						end,
						place = function(tc)
							local a = win:pos()
							return keepOnScreen(tc, a.X + 160 + 20, a.Y + 200)
						end,
					})
				end
				editThemeCard:open(c.level)
			end)

			flow:Row("COPYRIGHT", "About")
			flow:Row("COMMENTS", "Chat")
			c:setHeight(flow:bottom() + 10)
		end,
	})
end

-- There is no media session to read from inside Roblox, so the player shows its offline state.
local function buildSpotify(win)
	local width = 268 + 22
	local height = 145 + 22
	local view = viewport()
	local frame = Box(Stage, round(view.X - 268 - 90), 130, width, height)
	frame.Visible, frame.Active, frame.Name = false, true, "Spotify"
	local surface, shadow, ring, topGlow, rimStroke = buildSurface(frame, width, height, 16, false)
	local content = Box(frame, 0, 0, width, height)
	local scope = newScope(Root)
	local widget = { frame = frame, scope = scope, position = Vector2.new(frame.Position.X.Offset, 130), dragTarget = Vector2.new(frame.Position.X.Offset, 130) }
	scope.own = 0
	function widget:dragTo(target)
		widget.dragTarget = target
		if widget.moving then return end
		widget.moving = true
		Run(function(dt)
			widget.position = widget.position:Lerp(widget.dragTarget, 1 - exp(-9 * dt))
			if (widget.dragTarget - widget.position).Magnitude < 0.5 then widget.position = widget.dragTarget end
			setXY(frame, round(widget.position.X), round(widget.position.Y))
			scope:invalidateGrid(true)
			if widget.position == widget.dragTarget then
				widget.moving = false
				return false
			end
			return true
		end, scope)
	end
	local pad, w = 11, 268
	local music = Glyph(content, "MUSIC", 14)
	music:center(pad + music.boxW * 0.5, pad + 8.5)
	local heading = Label(content, "", round(pad + music.boxW + 7), capY(pad + 8.5, 11), 11, FontSemi)
	local dotsRect = Box(content, pad + w - 21, pad - 1, 21, 19, T.FrameInactive, 6)
	local dots = {}
	for i = -1, 1 do dots[i] = circle(Box(dotsRect, 9 + i * 4, 8, 3, 3, White, 1)) end
	local y = pad + 24
	local gc = Vector2.new(pad + w * 0.5, y + 24)
	local rings2 = {}
	for i = 3, 1, -1 do
		local r = 13 + i * 5
		local f = circle(Box(content, gc.X - r, gc.Y - r, r * 2, r * 2, nil, 1))
		rings2[i] = { Stroke(f, Accent, 1.5), f, r, i }
	end
	local glyph = Glyph(content, "MUSIC", 14)
	glyph:center(gc.X, gc.Y)
	local head = New("TextLabel", {
		Text = "", BackgroundTransparency = 1, FontFace = FontSemi, TextSize = 14, Size = UDim2.fromOffset(w, 20), Position = UDim2.fromOffset(pad, capY(y + 54.5, 14)),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	}, content)
	local sub = New("TextLabel", {
		Text = "", BackgroundTransparency = 1, FontFace = FontSemi, TextSize = 11, Size = UDim2.fromOffset(w, 16), Position = UDim2.fromOffset(pad, capY(y + 74, 11)),
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	}, content)
	local btnLabelW = measure(tr("Open Spotify"), 11, FontSemi)
	local btnW = round(min(w, btnLabelW + 52))
	local btn = Box(content, round(pad + (w - btnW) * 0.5), y + 88, btnW, 30, Accent, 15)
	local ext = Glyph(btn, "EXTERNAL_LINK_ALT", 14)
	local block = ext.boxW + 7 + btnLabelW
	local bx = (btnW - block) * 0.5
	ext:center(bx + ext.boxW * 0.5, 15)
	local btnLabel = Label(btn, "", round(bx + ext.boxW + 7), capY(15, 11), 11, FontSemi)
	local dotT, btnT = Anim(0, 15), Anim(0, 15)
	local function openSpotify()
		local ok = pcall(function()
			StarterGui:SetCore("OpenUrl", "https://open.spotify.com/")
		end)
		if not ok then
			pushNotification(tr("Spotify"), tr("Unable to open Spotify from this client."))
		end
	end
	local function paint()
		local a = scope.alpha
		surface.BackgroundColor3, surface.BackgroundTransparency = T.Popup, 1 - a
		if shadow then shadow.Transparency = 1 - 0.5 * a end
		if ring then ring.Color, ring.Transparency = T.PopupBorder, 1 - a end
		if topGlow then topGlow.BackgroundColor3, topGlow.BackgroundTransparency = Accent, 1 - a end
		if rimStroke then rimStroke.Transparency = 1 - a end
		music:paint(Accent, a)
		setText(heading, tr("Spotify"), 11, FontSemi)
		heading.TextColor3, heading.TextTransparency = T.Text, 1 - 0.85 * a
		dotsRect.BackgroundColor3, dotsRect.BackgroundTransparency = T.FrameInactive, 1 - 0.85 * dotT.v * a
		for _, d in dots do d.BackgroundColor3, d.BackgroundTransparency = T.Disabled:Lerp(T.Text, dotT.v), 1 - a end
		for i, r in rings2 do r[1].Color, r[1].Transparency = Accent, 1 - (0.13 / i) * a end
		glyph:paint(Accent, 0.85 * a)
		head.Text, head.TextColor3, head.TextTransparency = tr("Playback status unavailable"), T.Text, 1 - a
		sub.Text, sub.TextColor3, sub.TextTransparency = tr("Use Open Spotify to listen."), T.Disabled, 1 - a
		btn.BackgroundColor3, btn.BackgroundTransparency = Accent, 1 - (0.85 + 0.15 * btnT.v) * a
		ext:paint(White, a)
		setText(btnLabel, tr("Open Spotify"), 11, FontSemi)
		btnLabel.TextColor3, btnLabel.TextTransparency = White, 1 - a
	end
	dotT.cb, btnT.cb = paint, paint
	scope:paint(paint)
	Hit(scope, btn, { hover = function(b) btnT:to(b and 1 or 0) end, click = openSpotify })
	local optionsCard
	Hit(scope, dotsRect, {
		hover = function(b) dotT:to(b and 1 or 0) end,
		click = function()
			if not optionsCard then
				optionsCard = newCard({
					width = 272, name = "SpotifyOptions",
					place = function()
						return Vector2.new(widget.position.X + width + 8, widget.position.Y)
					end,
					build = function(c)
						local flow = newFlow({ parent = c.content, scope = c.scope, x = 10, y = 10, w = 252, rw = 252, card = c, level = c.level, win = win })
						flow:Row("EXTERNAL_LINK_ALT", "Open Spotify", openSpotify)
						flow:Separator()
						flow:Row("INFO_CIRCLE", "Account linking is not configured")
						c:setHeight(flow:bottom() + 10)
					end,
				})
			end
			optionsCard:open(0)
		end,
	})
	local shown = Anim(0, 12, function(v)
		scope:setAlpha(max(v, 0))
		frame.Visible = v > 0.004
	end, 0.004)
	table.insert(Windows, widget)
	frame.ZIndex = 50
	win.setSpotify = function(state) shown:to(state and 1 or 0) end
end

-- Reads the themes folder and settings.json, before anything is drawn.
local Overlay = {}
Overlay.__index = Overlay

function Overlay.new(o)
	local width = o.width or 200
	local height = o.height or 30
	local frame = Box(Stage, o.x or 100, o.y or 100, width, height)
	frame.Visible, frame.Active, frame.Name = false, true, o.name or "Overlay"
	frame.ZIndex = 500
	local surface, shadow, ring, topGlow, rimStroke, topGlowInset = buildSurface(frame, width, height, o.rounding or 8, true)
	local content = Box(frame, 0, 0, width, height)
	local scope = newScope(Root)
	local obj = setmetatable({
		frame = frame, surface = surface, shadow = shadow, ring = ring, topGlow = topGlow, topGlowInset = topGlowInset,
		rimStroke = rimStroke, content = content, scope = scope, width = width, height = height,
		position = Vector2.new(o.x or 100, o.y or 100), dragTarget = Vector2.new(o.x or 100, o.y or 100),
		visible = false,
	}, Overlay)

	scope.own = 1
	scope:paint(function()
		local a = scope.alpha
		surface.BackgroundColor3, surface.BackgroundTransparency = T.Popup, 1 - a
		if shadow then shadow.Transparency = 1 - 0.5 * a end
		if ring then ring.Color, ring.Transparency = T.PopupBorder, 1 - a end
		if topGlow then topGlow.BackgroundColor3, topGlow.BackgroundTransparency = Accent, 1 - a end
		if rimStroke then rimStroke.Transparency = 1 - a end
	end)

	function obj:dragTo(target)
		obj.dragTarget = target
		if obj.moving then return end
		obj.moving = true
		Run(function(dt)
			obj.position = obj.position:Lerp(obj.dragTarget, 1 - exp(-15 * dt))
			if (obj.dragTarget - obj.position).Magnitude < 0.5 then obj.position = obj.dragTarget end
			setXY(frame, round(obj.position.X), round(obj.position.Y))
			scope:invalidateGrid(true)
			if obj.position == obj.dragTarget then
				obj.moving = false
				return false
			end
			return true
		end, scope)
	end

	function obj:SetVisible(state)
		obj.visible = state
		frame.Visible = state
		if state then
			scope:refresh()
			wakeLoop()
		end
	end

	table.insert(Windows, obj)
	return obj
end

local function loadSaved(folder)
	local themeDir = folder .. "/themes"
	Files.folder(folder)
	Files.folder(themeDir)
	for name, palette in Palettes do
		local path = themeDir .. "/" .. name .. ".json"
		if not Files.read(path) then
			local colors = {}
			for key, entry in palette do colors[key] = toHex(entry[1], entry[2]) end
			Files.write(path, encodeJSON({ Colors = colors }))
		end
	end
	local names = {}
	for _, file in Files.list(themeDir) do
		if string.sub(file, -5) == ".json" then
			local name = string.sub(file, 1, -6)
			local data = decodeJSON(Files.read(themeDir .. "/" .. file))
			if type(data) == "table" and type(data.Colors) == "table" then
				local palette = {}
				for key, value in data.Colors do
					local color, alpha = fromHex(value)
					if color then palette[key] = { color, alpha } end
				end
				Palettes[name] = palette
				table.insert(names, name)
			end
		end
	end
	local rank = { Dark = 1, Light = 2 }
	table.sort(names, function(a, b)
		local x, y = rank[a] or 3, rank[b] or 3
		if x ~= y then return x < y end
		return a < b
	end)
	if #names > 0 then Library.ThemeNames = names end

	local saved = decodeJSON(Files.read(folder .. "/settings.json"))
	saved = type(saved) == "table" and saved or {}
	if Palettes[saved.theme] then Library.Theme = saved.theme end
	Accent = fromHex(saved.accent) or Accent
	if saved.language == 0 or saved.language == 1 or saved.language == 2 then Library.Language = saved.language end
	if type(saved.reducedMotion) == "boolean" then ReducedMotion = saved.reducedMotion end
	Library.ReducedMotion = ReducedMotion
	applyPalette()
	return saved
end

function Library:CreateWindow(o)
	o = o or {}
	buildScreen()
	preloadFonts()
	connectInput()
	local folder = o.Folder or "NeverloseReloaded"
	local saved = loadSaved(folder)
	local savedScale = tonumber(saved.scale)
	if savedScale and savedScale ~= 1 then
		if savedScale >= 0.5 and savedScale <= 2 then
			setRasterScale(savedScale)
		else
			warn("Ignored an out-of-range saved menu scale")
		end
	end
	local view = viewport()
	local requestedMaxSize = readWindowSize(o.MaxSize, Vector2.new(1280, 900), "MaxSize")
	local requestedMinSize = readWindowSize(o.MinSize, Vector2.new(min(680, requestedMaxSize.X), min(480, requestedMaxSize.Y)), "MinSize")
	assert(requestedMinSize.X <= requestedMaxSize.X and requestedMinSize.Y <= requestedMaxSize.Y, "MinSize cannot exceed MaxSize")
	local available = Vector2.new(max(320, view.X - 24), max(240, view.Y - 24))
	local maxSize = Vector2.new(min(requestedMaxSize.X, available.X), min(requestedMaxSize.Y, available.Y))
	local minSize = requestedMinSize
	minSize = Vector2.new(min(minSize.X, maxSize.X), min(minSize.Y, maxSize.Y))
	local requestedWidth, requestedHeight = o.Width or 800, o.Height or 600
	assert(type(requestedWidth) == "number" and requestedWidth > 0 and requestedWidth < huge, "Width must be finite and positive")
	assert(type(requestedHeight) == "number" and requestedHeight > 0 and requestedHeight < huge, "Height must be finite and positive")
	local initialWidth = clamp(requestedWidth, minSize.X, maxSize.X)
	local initialHeight = clamp(requestedHeight, minSize.Y, maxSize.Y)
	local start = o.Position or Vector2.new(floor((view.X - initialWidth) * 0.5), floor((view.Y - initialHeight) * 0.5))
	local frame = Box(Stage, start.X, start.Y, 800, 600)
	frame.Active, frame.Name, frame.ZIndex = true, "Menu", 10
	New("TextButton", { Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0) }, frame) -- frees a locked mouse
	local scope = newScope(Root)
	local win = setmetatable({
		frame = frame, scope = scope, position = start, dragTarget = start, tabs = {}, sideItems = {}, searchIndex = {}, Library = Library,
		folder = folder, saved = saved, store = { controls = {}, pending = {}, used = {} }, keybinds = {},
		width = 800, height = 600, minSize = minSize, maxSize = maxSize,
		requestedMinSize = requestedMinSize, requestedMaxSize = requestedMaxSize, resizeCallbacks = {},
	}, WindowMeta)
	scope.win = win
	win.settingsStore = { controls = {}, pending = type(saved.values) == "table" and saved.values or {}, used = {} }
	table.insert(Windows, win)
	CurrentWindow = win

	local waiting, timer = false, 0
	local function writeSettings()
		local values = {}
		for id, value in win.settingsStore.pending do values[id] = value end
		for id, control in win.settingsStore.controls do values[id] = control.get() end
		local current = win.configs and win.configs.current()
		Files.write(folder .. "/settings.json", encodeJSON({
			theme = Library.Theme, accent = toHex(Accent), language = Library.Language, scale = Scale, reducedMotion = ReducedMotion,
			lastConfig = current and current.name or nil, values = values,
		}))
	end
	-- Dragging the accent colour changes it every frame, so writes wait for a pause.
	function win.queueSettings()
		timer = 0.4
		if waiting then return end
		waiting = true
		Run(function(dt)
			timer -= dt
			if timer > 0 then return true end
			waiting = false
			writeSettings()
			return false
		end, scope)
	end
	win.settingsStore.onChange = win.queueSettings

	local side = Box(frame, 0, 0, 800, 600, T.Side, 20)
	Shadow(side, 22, 0.45, 4)
	local plate = Box(frame, 170, 0, 630, 600, T.Body, 20)
	local topClip = Box(frame, 170, 0, 630, 61)
	topClip.ClipsDescendants = true
	local topBar = Box(topClip, 0, 0, 630, 120, T.Top, 20)
	local topLine = Box(frame, 185, 60, 600, 1, T.Border)
	local sideLine = Box(frame, 10, 60, 150, 1, T.Border)
	local userLine = Box(frame, 10, 552, 150, 1, T.Border)
	scope:paint(function()
		side.BackgroundColor3, plate.BackgroundColor3, topBar.BackgroundColor3 = T.Side, T.Body, T.Top
		topLine.BackgroundColor3, sideLine.BackgroundColor3, userLine.BackgroundColor3 = T.Border, T.Border, T.Border
	end)

	-- wordmark, tracked by hand like the original
	local sideScope = newScope(scope)
	win.sideScope = sideScope
	local function tracked(text, x, y, size, font, spacing, alpha)
		local letters = {}
		local function set(value)
			local pen, visible = x, 0
			for i = 1, #value do
				local ch = string.sub(value, i, i)
				if ch ~= " " then
					visible += 1
					local letter = letters[visible]
					if not letter then
						letter = Label(frame, "", 0, y, size, font)
						letters[visible] = letter
					end
					setText(letter, ch, size, font)
					setXY(letter, round(pen), y)
					letter.Visible = true
				end
				pen += measure(ch, size, font) + spacing
			end
			for i = visible + 1, #letters do letters[i].Visible = false end
		end
		sideScope:paint(function()
			for _, letter in letters do
				letter.TextColor3, letter.TextTransparency = T.Text, 1 - alpha * sideScope.alpha
			end
		end)
		set(text)
		return set
	end
	local title = o.Title or o.Brand or "KILLARK"
	local subtitle = o.Subtitle or o.Description or o.SubBrand or "DREAM TEAM"
	local setTitle = tracked(title, 28, 15, 14, FontSemi, 0.935, 1)
	local setSubtitle = tracked(subtitle, 28, 31, 11, FontSemi, 2.17, 0.62)
	win.title, win.subtitle = title, subtitle
	function win:SetTitle(value)
		assert(type(value) == "string", "Title must be a string")
		win.title = value
		setTitle(value)
	end
	function win:SetSubtitle(value)
		assert(type(value) == "string", "Subtitle must be a string")
		win.subtitle = value
		setSubtitle(value)
	end
	function win:SetDescription(value)
		return win:SetSubtitle(value)
	end

	win.sideInner = Box(frame, 10, 70, 150, 470)

	-- content area
	local pagesScope = newScope(scope)
	win.pagesScope = pagesScope
	local pages = Box(frame, 185, 81, 600, 509)
	pages.ClipsDescendants = true
	win.pages = pages

	-- Task 3.4: Dynamic Window Resizing Grip
	local grip = Box(frame, 800 - 14, 600 - 14, 14, 14)
	local g1 = Box(grip, 6, 10, 6, 1, T.Disabled)
	local g2 = Box(grip, 10, 6, 1, 6, T.Disabled)
	scope:paint(function()
		g1.BackgroundColor3, g2.BackgroundColor3 = T.Disabled, T.Disabled
		g1.BackgroundTransparency = 1 - 0.5 * scope.alpha
		g2.BackgroundTransparency = 1 - 0.5 * scope.alpha
	end)

	function win:Resize(newW, newH)
		assert(type(newW) == "number" and newW == newW and newW > -huge and newW < huge and type(newH) == "number" and newH == newH and newH > -huge and newH < huge, "Resize expects finite numeric dimensions")
		newW = clamp(newW, win.minSize.X, win.maxSize.X)
		newH = clamp(newH, win.minSize.Y, win.maxSize.Y)
		win.width, win.height = newW, newH
		setWH(frame, newW, newH)
		setWH(side, newW, newH)
		setWH(plate, newW - 170, newH)
		setWH(topClip, newW - 170, 61)
		setWH(topBar, newW - 170, 120)
		setWH(topLine, newW - 200, 1)
		setXY(userLine, 10, newH - 48)
		setWH(win.sideInner, 150, newH - 130)
		setWH(pages, newW - 200, newH - 91)
		setXY(grip, newW - 14, newH - 14)
		for _, tab in win.tabs do
			tab.width = newW - 200
			for _, box in tab.boxes do
				local usable = newW - 200 - 8
				local columns = tab.weights
				local total = 0
				for i = 1, 2 do total += columns and columns[i] or 1 end
				local nextWidth = usable * (columns and columns[box.column] or 1) / total
				local nextFlowWidth = nextWidth - 24
				scaleGuiTreeX(box.content, nextFlowWidth / (box.width - 24))
				box.width = nextWidth
				box.flow:resize(nextFlowWidth)
				setXY(box.title, 12, 0)
				setText(box.title, tr(box.name), 11, FontSemi)
			end
			tab:layout()
		end
		local view = viewport()
		win.position = Vector2.new(clamp(win.position.X, 0, max(0, view.X - newW)), clamp(win.position.Y, 0, max(0, view.Y - newH)))
		win.dragTarget = win.position
		setXY(frame, round(win.position.X), round(win.position.Y))
		for _, callback in win.resizeCallbacks do callback(newW, newH) end
		scope:invalidateGrid(true)
	end
	connect(Stage:GetPropertyChangedSignal("AbsoluteSize"), function()
		local currentView = viewport()
		local fit = Vector2.new(max(320, currentView.X - 24), max(240, currentView.Y - 24))
		win.maxSize = Vector2.new(min(win.requestedMaxSize.X, fit.X), min(win.requestedMaxSize.Y, fit.Y))
		win.minSize = Vector2.new(min(win.requestedMinSize.X, win.maxSize.X), min(win.requestedMinSize.Y, win.maxSize.Y))
		win:Resize(win.width, win.height)
	end, scope)

	local resizing = false
	local startMouse, startSize = Vector2.zero, Vector2.zero
	Hit(scope, grip, {
		down = function(p)
			resizing = true
			startMouse = toStage(p)
			startSize = Vector2.new(win.width, win.height)
		end,
		drag = function(p)
			if not resizing then return end
			local delta = toStage(p) - startMouse
			win:Resize(startSize.X + delta.X, startSize.Y + delta.Y)
		end,
		up = function() resizing = false end,
	})
	win.pageAnim = Anim(0, 2.76, function(v)
		setXY(pages, 185, 81 - round(5 * v))
		pagesScope:setAlpha(v)
	end, 0.004)

	-- top bar
	local topScope = newScope(scope)
	win.topScope = topScope
	local presetPlate = Box(frame, 190, 15, 160, 30, T.FrameInactive, 6)
	local saveHit = Box(frame, 190, 15, 35, 30)
	local saveIcon = Glyph(frame, "SAVE", 14)
	saveIcon:center(190 + 17, 30)
	local divider = Box(frame, 225, 15, 1, 30, T.Divider)
	local dropHit = Box(frame, 225, 15, 125, 30)
	local dropClip = Box(frame, 225, 15, 100, 30)
	dropClip.ClipsDescendants = true
	local dropLabel = Label(dropClip, "", 0, capY(15, 12), 12)
	local dropChevron = Glyph(frame, "CHEVRON_DOWN", 14)
	local saveHot, dropHot, presetA = false, false, nil
	local function layoutTop()
		local current = win.configs and win.configs.current()
		local name = current and current.name or "None"
		local textW = measure(name, 12)
		local chevW = glyphContours("CHEVRON_DOWN").adv / 512 * 14
		local maxDropW = max(125, min(300, win.width - 500))
		local dropW = floor(clamp(textW + chevW + 40, 125, maxDropW))
		local btnW = 35 + dropW
		setWH(presetPlate, btnW, 30)
		setWH(dropHit, dropW, 30)
		local labelArea = dropW - chevW - 24
		setWH(dropClip, 12 + labelArea, 30)
		setText(dropLabel, name, 12)
		setXY(dropLabel, round(12 + (labelArea - min(textW, labelArea)) * 0.5), capY(15, 12))
		dropChevron:center(190 + btnW - 12 - chevW * 0.5, 30)
	end
	local function paintTop()
		local a = topScope.alpha
		presetPlate.BackgroundColor3 = T.FrameInactive
		presetPlate.BackgroundTransparency = 1 - (0.5 + presetA.v * 0.3) * a
		saveIcon:paint(saveHot and Accent or T.Text, a)
		divider.BackgroundColor3, divider.BackgroundTransparency = T.Divider, 1 - A.Divider * a
		dropLabel.TextColor3, dropLabel.TextTransparency = T.Text, 1 - a
		dropChevron:paint(T.Disabled, a)
	end
	presetA = Anim(0, 15, paintTop)
	topScope:paint(paintTop)
	local function presetsChanged()
		layoutTop()
		paintTop()
	end
	table.insert(win.resizeCallbacks, layoutTop)
	win.configs = newConfigs(win, presetsChanged)
	layoutTop()
	local function updatePreset()
		presetA:to((saveHot or dropHot) and 1 or 0)
		paintTop()
	end
	Hit(topScope, saveHit, {
		hover = function(b) saveHot = b; updatePreset() end,
		click = function()
			local current = win.configs.current()
			if current then
				win.configs.save(win.configs.selected)
				pushNotification(tr("Config Saved"), string.format(tr("Saved changes to %s"), current.name))
			end
		end,
	})
	local openConfigs = buildConfigPopup(win, win.configs, presetsChanged)
	Hit(topScope, dropHit, { hover = function(b) dropHot = b; updatePreset() end, click = openConfigs })
	buildSearch(win)

	-- account block
	local account = type(o.Account) == "table" and o.Account or {}
	local player = Players.LocalPlayer
	local profile = {
		name = account.Name or o.UserName or (player and player.Name) or "Guest",
		status = account.Status or o.UserStatus or "Local profile",
		actionText = account.ActionText,
		onAction = account.OnAction,
	}
	assert(type(profile.name) == "string" and profile.name ~= "", "Account.Name must be a non-empty string")
	assert(type(profile.status) == "string", "Account.Status must be a string")
	assert(profile.actionText == nil or type(profile.actionText) == "string", "Account.ActionText must be a string")
	assert(profile.onAction == nil or type(profile.onAction) == "function", "Account.OnAction must be a function")
	local userHit = Box(frame, 10, 552, 150, 40)
	table.insert(win.resizeCallbacks, function(_, newH) setXY(userHit, 10, newH - 48) end)
	Avatar.new(userHit, 8, 5, 30, sideScope)
	local nameL = Label(userHit, "", 47, 7, 12)
	local subL = Label(userHit, "", 47, 21, 11)
	local chev = Glyph(userHit, "CHEVRON_RIGHT", 13)
	chev:center(150 - 10 - chev.boxW * 0.5, 20)
	local cardT = Anim(0, 15)
	local cardOpen = false
	local userCard
	local function paintUser()
		local a = sideScope.alpha
		setText(nameL, profile.name, 12)
		setText(subL, tr(profile.status), 11)
		nameL.TextColor3, nameL.TextTransparency = T.Text, 1 - a
		subL.TextColor3, subL.TextTransparency = T.Disabled, 1 - a
		chev:paint(T.Disabled:Lerp(T.Text, cardT.v), a)
	end
	cardT.cb = paintUser
	sideScope:paint(paintUser)
	function win:SetAccount(values)
		assert(type(values) == "table", "SetAccount expects a table")
		if values.Name ~= nil then
			assert(type(values.Name) == "string" and values.Name ~= "", "Account.Name must be a non-empty string")
			profile.name = values.Name
		end
		if values.Status ~= nil then
			assert(type(values.Status) == "string", "Account.Status must be a string")
			profile.status = values.Status
		end
		if values.ActionText ~= nil then
			assert(type(values.ActionText) == "string" or values.ActionText == false, "Account.ActionText must be a string or false")
			profile.actionText = values.ActionText or nil
		end
		if values.OnAction ~= nil then
			assert(type(values.OnAction) == "function" or values.OnAction == false, "Account.OnAction must be a function or false")
			profile.onAction = values.OnAction or nil
		end
		paintUser()
		if userCard then userCard.scope:refresh() end
	end
	local userHover = false
	Hit(sideScope, userHit, {
		hover = function(b) userHover = b; cardT:to((b or cardOpen) and 1 or 0) end,
		click = function()
			if not userCard then
				userCard = buildUserCard(win, profile)
				userCard.onState = function(state) cardOpen = state; cardT:to((state or userHover) and 1 or 0) end
			end
			userCard:open(0)
		end,
	})
	buildSpotify(win)

	if o.ToggleKey ~= false then
		local key = o.ToggleKey or Enum.KeyCode.RightShift
		connect(UserInputService.InputBegan, function(input, processed)
			if not processed and input.KeyCode == key then
				frame.Visible = not frame.Visible
				if not frame.Visible then
					closePopupsTo(0)
				elseif scope.dirty then
					scope:refresh()
				end
			end
		end, scope)
	end
	win.Screen = Screen
	-- Task 3.2: Draggable Watermark Overlay
	local watermarkOverlay = Overlay.new({ width = 240, height = 26, name = "Watermark", rounding = 6 })
	local wmLabel = Label(watermarkOverlay.content, "", 10, capY(13, 11), 11, FontMedium)
	local fpsTimer, frameCount, curFps = 0, 0, 60
	local cancelWatermarkJob
	local function updateWatermark(dt)
		fpsTimer += dt
		frameCount += 1
		if fpsTimer < 0.25 then return end
		curFps = round(frameCount / fpsTimer)
		frameCount, fpsTimer = 0, 0
		local ping = 0
		if StatsService then
			pcall(function() ping = round(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
		end
		local cfgName = (win.configs and win.configs.current() and win.configs.current().name) or "default"
		local txt = (o.Brand or "Neverlose") .. " | " .. curFps .. " fps | " .. ping .. " ms | " .. cfgName
		setText(wmLabel, txt, 11, FontMedium)
		local measuredW = max(180, ceil(measure(txt, 11, FontMedium)) + 20)
		if watermarkOverlay.width ~= measuredW then
			watermarkOverlay.width = measuredW
			setWH(watermarkOverlay.frame, measuredW, 26)
			resizeSurface(watermarkOverlay, measuredW, 26)
			watermarkOverlay.scope:invalidateGrid(true)
		end
	end
	local function startWatermarkUpdates()
		if cancelWatermarkJob then return end
		cancelWatermarkJob = Run(function(dt)
			if not watermarkOverlay.visible then
				cancelWatermarkJob = nil
				return false
			end
			updateWatermark(dt)
			return true
		end, watermarkOverlay.scope)
	end
	watermarkOverlay.scope:paint(function()
		wmLabel.TextColor3 = T.Text
		wmLabel.TextTransparency = 1 - watermarkOverlay.scope.alpha
	end)

	function win:SetWatermark(state)
		local visible = state == true
		watermarkOverlay:SetVisible(visible)
		if visible then
			fpsTimer, frameCount = 0, 0
			startWatermarkUpdates()
		elseif cancelWatermarkJob then
			cancelWatermarkJob()
			cancelWatermarkJob = nil
		end
	end

	-- Task 3.2: Draggable Active Keybinds HUD Overlay
	local keybindHUD = Overlay.new({ width = 180, height = 30, name = "KeybindHUD", rounding = 8 })
	local kbTitle = Label(keybindHUD.content, tr("Keybinds"), 10, capY(15, 12), 12, FontSemi)
	local kbRowsContainer = Box(keybindHUD.content, 0, 30, 180, 0)
	keybindHUD.scope:paint(function()
		kbTitle.TextColor3 = T.Title
		kbTitle.TextTransparency = 1 - keybindHUD.scope.alpha
	end)

	local hudRows = {}
	refreshKeybindHUD = function()
		if not keybindHUD.visible then return end
		local activeBinds = {}
		for _, b in win.keybinds do
			if b.showInList and b:IsActive() then
				table.insert(activeBinds, b)
			end
		end
		for i, b in activeBinds do
			local r = hudRows[i]
			if not r then
				local rowF = Box(kbRowsContainer, 6, (i - 1) * 22, 168, 22)
				rowF.ClipsDescendants = true
				local nameL = ScrollText(rowF, 4, 0, 96, 22, 11, nil, keybindHUD.scope)
				local modeL = Label(rowF, "", 104, 0, 10, FontSemi)
				modeL.Size = UDim2.fromOffset(60, 22)
				modeL.TextXAlignment = Enum.TextXAlignment.Right
				modeL.TextYAlignment = Enum.TextYAlignment.Center
				modeL.TextTruncate = Enum.TextTruncate.AtEnd
				keybindHUD.scope:paint(function()
					nameL:paint(T.Text, keybindHUD.scope.alpha)
					modeL.TextColor3 = Accent
					modeL.TextTransparency = 1 - keybindHUD.scope.alpha
				end)
				Hit(keybindHUD.scope, nameL.clip, { hover = function(b) nameL:hover(b) end })
				r = { frame = rowF, nameLabel = nameL, modeLabel = modeL }
				hudRows[i] = r
			end
			local _, mode = b:Get()
			r.nameLabel:set(tr(b.name))
			r.nameLabel:paint(T.Text, keybindHUD.scope.alpha)
			setText(r.modeLabel, "[" .. string.upper(mode) .. "]", 10, FontSemi)
			r.frame.Visible = true
		end
		for i = #activeBinds + 1, #hudRows do
			hudRows[i].frame.Visible = false
		end
		local totalH = 30 + #activeBinds * 22 + 6
		if keybindHUD.height ~= totalH then
			keybindHUD.height = totalH
			setWH(keybindHUD.frame, 180, totalH)
			resizeSurface(keybindHUD, 180, totalH)
			keybindHUD.scope:invalidateGrid(true)
		end
	end

	function win:SetKeybindList(state)
		keybindHUD:SetVisible(state == true)
		refreshKeybindHUD()
	end

	win.Notify = function(_, title, text) pushNotification(title, text) end
	win:Resize(initialWidth, initialHeight)
	return win
end

--[[ ---------------------------------------- Icon tabs, chips, ESP card -------------------- ]]

local function IconTabs(win, parent, scope, topRight, icons, labels, trailing, onClick)
	local h, pad, gap = 26, 9, 4
	local count = #icons
	local segs = {}
	local active, held = 1, nil
	local trailingHolder
	local function layout()
		local total = 0
		for i, seg in segs do
			seg.width = pad * 2 + seg.iconW + seg.open.v * (6 + measure(tr(labels[i]), 12))
			total += seg.width + gap
		end
		local trailingW = pad * 2 + trailing.iconW
		total += trailingW + gap * 2
		total -= gap
		local x = (win and win.width - 200 or topRight) - total
		for _, seg in segs do
			setXY(seg.frame, round(x), 0)
			setWH(seg.frame, round(seg.width), h)
			setWH(seg.plate, round(seg.width), h)
			x += seg.width + gap
		end
		x += gap
		setXY(trailing.frame, round(x), 0)
	end
	local function paintSeg(i)
		local seg = segs[i]
		local a = scope.alpha
		local plateA = max(seg.open.v, max(seg.hot.v, i == held and 1 or 0) * 0.5)
		seg.plate.BackgroundColor3, seg.plate.BackgroundTransparency = T.FrameInactive, 1 - 0.9 * plateA * a
		local color = T.Disabled:Lerp(T.Text, max(seg.hot.v, i == held and 1 or 0)):Lerp(Accent, seg.open.v)
		seg.glyph:paint(color, a)
		setText(seg.label, tr(labels[i]), 12)
		seg.label.TextColor3, seg.label.TextTransparency = color, 1 - seg.open.v * a
	end
	for i, name in icons do
		local frame = Box(parent, 0, 0, 40, h)
		frame.ClipsDescendants = true
		local plate = Box(frame, 0, 0, 40, h, T.FrameInactive, 8)
		local glyph = Glyph(frame, name, 14)
		glyph:center(pad + glyph.boxW * 0.5, 13)
		local label = Label(frame, "", round(pad + glyph.boxW + 6), capY(13, 12), 12)
		local seg = { frame = frame, plate = plate, glyph = glyph, label = label, iconW = glyph.boxW }
		seg.open = Anim(i == 1 and 1 or 0, 14, function() layout(); paintSeg(i) end)
		seg.hot = Anim(0, 15, function() paintSeg(i) end)
		segs[i] = seg
		scope:paint(function() paintSeg(i) end)
		Hit(scope, frame, {
			hover = function(b) seg.hot:to(b and 1 or 0) end,
			click = function()
				if i ~= count then
					active = i
					for k, s in segs do s.open:to(k == active and 1 or 0) end
				end
				onClick(i)
			end,
		})
	end
	local frame = Box(parent, 0, 0, 30, h)
	local plate = Box(frame, 0, 0, 30, h, T.FrameInactive, 8)
	local glyph = Glyph(frame, "EXPAND_ALT", 14)
	glyph:center(pad + glyph.boxW * 0.5, 13)
	trailing.frame, trailing.iconW = frame, glyph.boxW
	setWH(frame, round(pad * 2 + glyph.boxW), h)
	setWH(plate, round(pad * 2 + glyph.boxW), h)
	local hot = Anim(0, 15)
	local function paintTrailing()
		local a = scope.alpha
		plate.BackgroundColor3, plate.BackgroundTransparency = T.FrameInactive, 1 - 0.45 * hot.v * a
		glyph:paint(T.Disabled:Lerp(T.Text, hot.v), a)
	end
	hot.cb = paintTrailing
	scope:paint(paintTrailing)
	Hit(scope, frame, { hover = function(b) hot:to(b and 1 or 0) end, click = function() onClick(count + 1) end })
	scope:paint(layout)
	table.insert(win.resizeCallbacks, layout)
	return { setHeld = function(i)
		held = i
		for k in segs do paintSeg(k) end
	end }
end

local function Chips(flow, labels, getValues, refreshers)
	local h, pad, gap, gapY = 24, 11, 6, 10
	local avail, origin = flow.rw, flow.y
	local x, y = 0, 0
	local scope = flow.scope
	for i, label in labels do
		local width = ceil(measure(tr(label), 12) + pad * 2)
		if x > 0 and x + width > avail then
			x = 0
			y += h + gapY
		end
		local chip = Box(flow.parent, flow.x + x, origin + y, width, h, T.FrameInactive, 8)
		local stroke = Stroke(Box(chip, 1, 1, width - 2, h - 2, nil, 7), Accent)
		local text = Label(chip, "", pad, capY(12, 12), 12)
		local hot, on = Anim(0, 15), Anim(getValues()[i] and 1 or 0, 14)
		local function paint()
			local a = scope.alpha
			local bgAlpha = (0.55 + 0.35 * hot.v) + ((0.22 + 0.08 * hot.v) - (0.55 + 0.35 * hot.v)) * on.v
			chip.BackgroundColor3 = T.FrameInactive:Lerp(Accent, on.v)
			chip.BackgroundTransparency = 1 - bgAlpha * a
			stroke.Color, stroke.Transparency = Accent, 1 - 0.55 * on.v * a
			setText(text, tr(label), 12)
			text.TextColor3 = T.Disabled:Lerp(T.Text, hot.v):Lerp(Accent, on.v)
			text.TextTransparency = 1 - a
		end
		hot.cb, on.cb = paint, paint
		scope:paint(paint)
		Hit(scope, chip, {
			hover = function(b) hot:to(b and 1 or 0) end,
			click = function()
				local values = getValues()
				values[i] = not values[i]
				on:to(values[i] and 1 or 0)
			end,
		})
		table.insert(refreshers, function() on:to(getValues()[i] and 1 or 0) end)
		x += width + gap
	end
	flow.y = origin + y + h
end

local function buildAmbience(win)
	local frame = win.frame
	local clip = Box(frame, 170, 0, 630, 600)
	clip.ClipsDescendants = true
	clip.Visible = false
	clip.ZIndex = 40
	local scrim = Box(clip, -20, 0, 650, 600, T.Body, 20)
	local edge = Box(clip, 0, 0, 1, 600, T.Border)
	local scope = newScope(win.scope)
	scope.inert = true
	local content = newScope(scope)
	local holder = Box(clip, 0, 0, 630, 600)
	local state = 0
	local isOpen = false
	local cancelTransition
	local function paint()
		local scrimA = sat(state / 0.45)
		scrim.BackgroundColor3, scrim.BackgroundTransparency = T.Body, 1 - scrimA
		edge.BackgroundColor3, edge.BackgroundTransparency = T.Border, 1 - 0.6 * scrimA
	end
	scope:paint(paint)
	local function apply()
		paint()
		content:setAlpha(max(sat((state - 0.45) / 0.55), 0.0001))
		clip.Visible = state > 0
	end
	local function setOpen(open)
		isOpen = open
		scope.inert = not open
		win.sideScope.inert = open
		win.pagesScope.inert = open
		win.topScope.inert = open
		if cancelTransition then cancelTransition() end
		cancelTransition = Run(function(dt)
			if isOpen then
				state += (1 - state) * (1 - exp(-15 * dt))
				if state > 0.998 then state = 1 end
			else
				state = max(0, state - dt / 0.16)
				if state < 0.01 then state = 0 end
			end
			apply()
			if (isOpen and state == 1) or state == 0 then
				cancelTransition = nil
				return false
			end
			return true
		end, scope)
	end
	-- corner buttons
	IconButton(holder, content, "TIMES", 630 - 14 - 24, 12, 24, 24, DimHot, function() setOpen(false) end)
	IconButton(holder, content, "ELLIPSIS_H", 630 - 14 - 48 - 2, 12, 24, 24, DimHot, function() end)
	local gap = 14
	local usable = 630 - gap * 2 - gap
	local w1 = floor(usable * 0.454)
	local w2 = usable - w1
	-- left column: no box round the map list
	local title = Label(holder, "", gap + 12, 46, 11, FontSemi)
	content:paint(function()
		setText(title, tr("MAP SELECTION"), 11, FontSemi)
		title.TextColor3, title.TextTransparency = T.Title, 1 - 0.5 * content.alpha
	end)
	local left = newFlow({ parent = holder, scope = content, x = gap, y = 46 + 18, w = w1, rw = w1, spacing = gap, win = win })
	local mapRows = {}
	local mapChoice = 1
	local function pickMap(i)
		mapChoice = i
		for k, r in mapRows do r:Select(k == i) end
	end
	win:Flag("Ambience/MAP SELECTION", function() return mapChoice end, function(v) if mapRows[v] then pickMap(v) end end)
	mapRows[1] = left:Framed("Global", { Selected = true, ActionIcon = "ELLIPSIS_H", Action = function() end, Callback = function() pickMap(1) end, Width = w1 })
	mapRows[2] = left:Framed("Main Menu", { ActionIcon = "FILE_IMPORT", ActionLabel = "Add", Action = function() pushNotification(tr("Ambience"), tr("Added the current map")) end, Callback = function() pickMap(2) end, Width = w1 })
	if mapChoice ~= 1 then pickMap(mapChoice) end
	-- right column: the effects box
	local boxX = gap + w1 + gap
	local holderBox = Box(holder, boxX, 46, w2, 400)
	local fill = Box(holderBox, 0, 18, w2, 380, T.Group, 13)
	local lineF = Box(holderBox, 1, 19, w2 - 2, 378, nil, 12)
	local line = Stroke(lineF, T.Border)
	local boxTitle = Label(holderBox, "", 12, 0, 11, FontSemi)
	local inner = Box(holderBox, 0, 18, w2, 380)
	local flow = newFlow({ parent = inner, scope = content, x = 12, y = 6, w = w2 - 24, rw = w2 - 24, spacing = 6, separators = true, level = 0, win = win, path = "Ambience/EFFECTS", store = win.store })
	flow.hostRight = function() return toStage(holderBox.AbsolutePosition).X + w2 end
	content:paint(function()
		local a = content.alpha
		fill.BackgroundColor3, fill.BackgroundTransparency = T.Group, 1 - a
		line.Color, line.Transparency = T.Border, 1 - a
		setText(boxTitle, tr("EFFECTS"), 11, FontSemi)
		boxTitle.TextColor3, boxTitle.TextTransparency = T.Title, 1 - 0.5 * a
	end)
	local fxColors = {
		Color3.new(.66, .62, .86), Color3.new(1, 1, 1), Color3.new(.85, .85, .88), Color3.new(.88, .88, .92), Color3.new(1, 1, 1), Color3.new(.8, .84, .92),
		Color3.new(.9, .9, .95), Color3.new(1, 1, 1), Color3.new(.86, .88, .95), Color3.new(.84, .86, .94), Color3.new(.82, .86, .96),
	}
	local fxLabels = { "Nightmode", "Fullbright", "Exposure", "Sunlight", "Sky", "Fog", "Bloom", "Vignette", "Local Contrast", "Color Correction", "Depth of Field" }
	local fxDots = { false, false, true, false, false, false, true, false, true, true, true }
	for i, label in fxLabels do
		if fxDots[i] then
			flow:Toggle({ Name = label, Tip = false, Options = function(f)
				f:Option("ADJUST", "Mode", { "Default", "Soft", "Strong" }, 1)
				f:Separator()
				f:Section({ Border = false }, function(s) s:Slider({ Name = "Amount", Min = 0, Max = 100, Default = 50 }) end)
			end })
		else
			flow:Toggle({ Name = label, Tip = false, Color = newColor(fxColors[i]) })
		end
	end
	flow:SubMenu({ Name = "Weather", Build = function(c)
		c:Section({ Border = true }, function(s)
			s:Toggle({ Name = "[WIND]Wind", Tip = false, Options = function(f) f:PopupToggle("TREE", "Affect Foliage", false) end })
			s:Toggle({ Name = "[TINT]Model Wetness", Tip = false, Options = function(f) f:PopupToggle("USER", "Players Only", false) end })
		end)
		c:Section({ Border = true }, function(s)
			s:Toggle({ Name = "[BOLT]Thunder", Tip = false, Color = newColor(Color3.new(.44, .69, 1)) })
			s:Toggle({ Name = "[CLOUD_SHOWERS]Rain", Tip = false, Color = newColor(Color3.new(.86, .91, 1)) })
			s:Toggle({ Name = "[SNOWFLAKE]Snow", Tip = false, Color = newColor(Color3.new(.95, .95, .97)) })
		end)
	end })
	flow:SubMenu({ Name = "Removals", Build = function(c)
		c:Section({ Border = true }, function(s)
			s:Toggle({ Name = "Smoke", Tip = false })
			s:Toggle({ Name = "Flashbang", Tip = false })
			s:Toggle({ Name = "Scope Blur", Tip = false })
		end)
	end })
	local total = flow.y - 6 + 6 + 18
	setWH(holderBox, w2, total)
	setWH(fill, w2, total - 18)
	setWH(lineF, w2 - 2, total - 20)
	setWH(inner, w2, total - 18)
	apply()
	return function() setOpen(true) end
end

--[[ ---------------------------------------- Demo ------------------------------------------ ]]

function Library:Demo(o)
	local win = Library:CreateWindow(o)
	local function rows(box, count, default)
		for i = 1, count do box:Toggle({ Name = tostring(i), Default = default }) end
	end
	local items = { "Head", "Chest", "Stomach", "Legs" }

	win:Group("AIMBOT")
	local rage = win:Tab({ Name = "Rage", Icon = "CROSSHAIRS" })
	local legit = win:Tab({ Name = "Legit", Icon = "MOUSE" })
	win:Group("COMMON")
	local visuals = win:Tab({ Name = "Visuals", Icon = "IMAGE" }):EnableChildren()
	local players = win:Tab({ Name = "Players", Icon = "USER", Parent = visuals })
	local world = win:Tab({ Name = "World", Icon = "GLOBE", Parent = visuals })
	local shader = win:Tab({ Name = "Shader", Icon = "MAGIC", Parent = visuals })
	local misc = win:Tab({ Name = "Miscellaneous", Icon = "SLIDERS_H" }):EnableChildren()
	local components = win:Tab({ Name = "Components", Icon = "SLIDERS_H", Parent = misc })
	local curveLab = win:Tab({ Name = "Curve Lab", Icon = "VECTOR_SQUARE", Parent = misc })
	local typography = win:Tab({ Name = "Typography", Icon = "FONT", Parent = misc })

	-- Rage
	local main = rage:Box({ Name = "MAIN", Column = 1 })
	local enabledToggle = main:Toggle({ Name = "Enabled", Default = true })
	main:Keybind({ Name = "Aim Key", Default = Enum.KeyCode.E, Mode = "Hold", ShowInList = true })
	main:Textbox({ Name = "Target Tag", Placeholder = "Enter name...", Default = "Enemy" })
	main:RangeSlider({ Name = "Reaction Delay", Min = 0, Max = 500, Default = { 60, 140 }, Format = "%d ms" })
	main:ButtonRow({ Name = "Save Preset" }, { Name = "Reset All", Confirm = true })
	local silentAim = main:Toggle({ Name = "Silent Aim", Default = true })
	silentAim:DependsOn(enabledToggle, true)
	main:Toggle({ Name = "Automatic Fire", Default = true })
	main:Toggle({ Name = "Aim Through Walls", Default = true })
	main:Slider({ Name = "Field Of View", Min = 0, Max = 180, Default = 90, Tip = "Adjust the field of view in degrees." })
	main:CurveEditor({ Name = "Smoothing Curve" })
	rows(rage:Box({ Name = "SELECTION", Column = 1 }), 6, true)
	rows(rage:Box({ Name = "OTHER", Column = 2 }), 6, true)
	local anti = rage:Box({ Name = "ANTI-AIM", Column = 2 })
	anti:Toggle({ Name = "Enabled", Default = false })
	local function pitchBody(card)
		card:Section({ Border = true }, function(s)
			s:Toggle({ Name = "Checkbox", Default = true })
			s:Combo({ Name = "Combo", Options = items, Tip = "Select one item from the list." })
			s:Multi({ Name = "Multi", Options = items, Default = { true, true, true, false }, Tip = "Select one or more items. Click a selected item again to remove it." })
		end)
		card:Section({ Border = true }, function(s)
			s:Toggle({ Name = "[RUNNING]Checkbox" })
			s:Toggle({ Name = "[AWARD]Checkbox", Tip = "Hello, this is info box!" })
			s:Toggle({ Name = "Checkbox" })
			s:Slider({ Name = "Slider", Min = 0, Max = 100, Default = 90, Tip = "Drag the bar to adjust the value from 0 to 100." })
		end)
	end
	for _, name in { "Pitch", "Yaw", "Freestanding", "Mouse Override" } do
		anti:SubMenu({ Name = name, Build = pitchBody })
	end

	-- Legit
	local baby = legit:Box({ Name = "Baby", Column = 1, Height = -0.5 })
	baby:Toggle({ Name = "Kill Effect", Default = true, Color = newColor(Color3.new(.96, .22, .3)) })
	baby:Color({ Name = "Additional Colors", Color = newColor(Color3.new(1, .22, .3), 1, Color3.new(1, .58, .66), 1, true) })
	baby:Toggle({ Name = "Glow", Tip = false, Color = newColor(Color3.new(.32, .49, .99)), ColorExtras = function(f)
		f:Section({ Border = false }, function(s)
			s:Slider({ Name = "Spread Force", Min = 0, Max = 100, Default = 20 })
			s:Slider({ Name = "Speed", Min = 0, Max = 100, Default = 45 })
		end)
	end })
	baby:Toggle({ Name = "Name", Tip = false, Color = newColor(White, 210 / 255), ColorExtras = function(f)
		f:Option("FONT", "Font", { "Regular", "Bold", "Italic" }, 1)
		f:Option("FONT_CASE", "Case", { "Default", "Uppercase", "Lowercase" }, 1)
		f:Separator()
		f:PopupToggle("USER_CIRCLE", "Draw Avatar", false)
	end })
	local function trajectory(f)
		f:Option("PROJECT_DIAGRAM", "Style", { "Line", "Dots", "Arrows" }, 1)
		f:PopupToggle("SKULL", "Show On Death", true)
		f:Separator()
		f:Section({ Border = false }, function(s) s:Slider({ Name = "Opacity", Min = 0, Max = 100, Default = 80 }) end)
	end
	local ad = legit:Box({ Name = "Ad", Column = 1, Height = 0 })
	ad:Toggle({ Name = "Grenade Trajectory", Tip = false, Options = trajectory })
	ad:SubMenu({ Name = "Weather", Build = function(c)
		c:Section({ Border = true }, function(s)
			s:Toggle({ Name = "[WIND]Wind", Tip = false })
			s:Toggle({ Name = "[TINT]Model Wetness", Tip = false })
		end)
		c:Section({ Border = true }, function(s)
			s:Toggle({ Name = "[BOLT]Thunder", Tip = false, Color = newColor(Color3.new(.66, .8, 1)) })
			s:Toggle({ Name = "[CLOUD_SHOWERS]Rain", Tip = false, Color = newColor(Color3.new(.86, .91, 1)) })
			s:Toggle({ Name = "[SNOWFLAKE]Snow", Tip = false, Color = newColor(Color3.new(.95, .95, .97)) })
		end)
	end })
	local nonIcon = legit:Box({ Name = "Non icon name", Column = 2, Height = 0 })
	nonIcon:Color({ Name = "Layout", Slots = {
		{ name = "Layout", value = newColor(Color3.new(.08, .08, .08)) }, { name = "Background", value = newColor(Black) },
		{ name = "Border", value = newColor(Color3.new(.16, .17, .21)) }, { name = "Accent", value = newColor(Color3.new(.32, .49, .99)) },
		{ name = "Text", value = newColor(Color3.new(.55, .56, .6)) },
	} })

	-- Players
	local enemy = players:Box({ Name = "ENEMY", Column = 1 })
	enemy:Toggle({ Name = "Enabled" })
	enemy:Toggle({ Name = "Offscreen Arrow", Color = newColor(White) })
	enemy:Toggle({ Name = "Sounds", Color = newColor(Color3.new(1, .29, .47)) })
	local model = players:Box({ Name = "ENEMY MODEL", Column = 1 })
	local modes = { "Disabled", "Flat", "Glow", "Chams" }
	model:Combo({ Name = "Player", Options = modes, Color = newColor(Color3.new(.45, .45, .95)) })
	model:Combo({ Name = "Behind Walls", Options = modes, Color = newColor(Color3.new(.36, .9, .9)) })
	model:Combo({ Name = "On Shot", Options = modes, Color = newColor(Color3.new(.8, .86, .86)) })
	model:Combo({ Name = "History", Options = modes, Color = newColor(Color3.new(.85, .85, .87)) })
	model:Combo({ Name = "Ragdolls", Options = modes, Color = newColor(Color3.new(.69, .66, .85)) })
	model:Toggle({ Name = "Kill Effect", Color = newColor(Color3.new(.96, .22, .3)) })
	model:Toggle({ Name = "Glow", Color = newColor(Color3.new(.72, .73, .98)) })
	do
		local page, scope = players.page, players.pageScope
		local espCard
		local sections = {
			{ "Main", { "Bounding Box", "Name", "Distance", "Health Bar", "Ammo Bar", "Skeleton" } },
			{ "Flags", { "Unarmored", "Defuser", "Blind", "Scoped", "Reload", "Immunity", "Slowed", "Vulnerable", "Bomb", "Hostage", "Defuse", "Pin Pulled", "Money", "Order Priority", "Delay" } },
			{ "Weapon", { "Text", "Icon", "Readiness Bar", "Bomb", "Defuser", "Taser" } },
			{ "Aimbot", { "Hit Chance", "Hitboxes" } },
		}
		-- section -> side (1 Enemies, 2 Friends) -> ticked chips; each side keeps its own set
		local espValues = {
			{ { true, true, false, true, false, false }, { true, false, false, false, false, false } },
			{ {}, {} }, { { true, false, false, false, false, false }, {} }, { {}, {} },
		}
		local espSide = 1
		local refreshers = {}
		local function refreshChips()
			for _, refresh in refreshers do refresh() end
		end
		for i, section in sections do
			for side, sideName in { "Enemies", "Friends" } do
				win:Flag("Players/ESP Items/" .. section[1] .. "/" .. sideName, function()
					local names = {}
					for k, label in section[2] do
						if espValues[i][side][k] then table.insert(names, label) end
					end
					return names
				end, function(names)
					if type(names) ~= "table" then return end
					for k, label in section[2] do espValues[i][side][k] = table.find(names, label) ~= nil end
					refreshChips()
				end)
			end
		end
		local tabsObj
		local espOpen = false
		local handleHot, handleTurn
		local function ensureCard()
			if espCard then return espCard end
			espCard = newCard({
				width = 296, padding = 12, name = "EspItems",
				place = function(c)
					local a = toStage(page.AbsolutePosition)
					return keepOnScreen(c, a.X + 304, a.Y + 34)
				end,
				build = function(c)
					local title = Label(c.content, "", 13, capY(20, 14), 14, FontSemi)
					c.scope:paint(function()
						setText(title, tr("ESP Items"), 14, FontSemi)
						title.TextColor3, title.TextTransparency = T.Text, 1 - c.scope.alpha
					end)
					local flow = newFlow({ parent = c.content, scope = c.scope, x = 12, y = 36, w = 272, rw = 272, card = c, level = c.level, win = win })
					for i, section in sections do
						flow:Section({ Border = true, Pad = 10, Inset = 10 }, function(s)
							local head = Label(s.parent, "", s.x, s.y + capY(7.5, 12), 12)
							s.scope:paint(function()
								setText(head, tr(section[1]), 12)
								head.TextColor3, head.TextTransparency = T.Text, 1 - s.scope.alpha
							end)
							s.y += 15 + 10
							Chips(s, section[2], function() return espValues[i][espSide] end, refreshers)
						end)
					end
					c:setHeight(flow:bottom() + 12)
				end,
			})
			espCard.onState = function(state)
				espOpen = state
				tabsObj.setHeld(state and 3 or nil)
				handleTurn:to(state and 1 or 0)
				handleHot:to(state and 1 or 0)
			end
			return espCard
		end
		-- chip widths depend on the language, so the card is rebuilt the next time it opens
		win.onLanguage = function()
			if espCard then
				espCard:destroy()
				espCard = nil
				table.clear(refreshers)
			end
		end
		tabsObj = IconTabs(win, page, scope, 600, { "USER", "USER_MINUS", "LIST_ALT" }, { "Enemies", "Friends", "ESP Items" }, {}, function(i)
			if i == 3 then
				ensureCard():open(0)
			elseif i <= 2 then
				espSide = i
				refreshChips()
			end
		end)
		-- the pull-up handle: a clip keeps the single plate's bottom edge square
		local hw, hh = 46, 18
		local handle = Box(page, round(304 + (296 - hw) * 0.5), 509 - hh, hw, hh)
		handle.ClipsDescendants = true
		local handlePlate = Box(handle, 0, 0, hw, hh * 2, T.FrameInactive, 9)
		local upChev = Shape(handle, strokeContours({ -4.5, 3, 0, -3, 4.5, 3 }, 1.6), 1, "HANDLE_U"):at(hw * 0.5, hh * 0.5)
		local dnChev = Shape(handle, strokeContours({ -4.5, -3, 0, 3, 4.5, -3 }, 1.6), 1, "HANDLE_D"):at(hw * 0.5, hh * 0.5)
		local function paintHandle()
			local a = scope.alpha
			local hot = handleHot.v
			handlePlate.BackgroundColor3 = T.FrameInactive
			handlePlate.BackgroundTransparency = 1 - (0.55 + 0.35 * hot) * a
			local color = T.Disabled:Lerp(T.Text, hot)
			upChev:paint(color, a * (1 - handleTurn.v))
			dnChev:paint(color, a * handleTurn.v)
		end
		handleHot, handleTurn = Anim(0, 15, paintHandle), Anim(0, 14, paintHandle)
		scope:paint(paintHandle)
		Hit(scope, handle, {
			hover = function(b) handleHot:to((b or espOpen) and 1 or 0) end,
			click = function() ensureCard():open(0) end,
		})
	end

	-- World
	local function worldPopup(card)
		card:Section({ Border = true }, function(s)
			s:Toggle({ Name = "Enabled", Default = true, Tip = false })
			s:Combo({ Name = "Style", Options = { "Default", "Filled", "Outlined" } })
			s:Toggle({ Name = "Outline", Tip = false })
		end)
		card:Section({ Border = false }, function(s) s:Slider({ Name = "Size", Min = 0, Max = 100, Default = 45 }) end)
	end
	local selectItems, overlayItems = { "Select", "Always", "In Air", "On Key" }, { "Default", "Classic", "Minimal" }
	local openAmbience = buildAmbience(win)
	local view = world:Box({ Name = "VIEW", Column = 1, RowSpacing = 7, PadY = 6 })
	for _, name in { "View Options", "Scope Options", "Viewmodel Options", "Perspective Options" } do view:SubMenu({ Name = name, Build = worldPopup }) end
	view:Combo({ Name = "Unlock Spectating", Options = selectItems })
	view:Combo({ Name = "Visual Recoil", Options = selectItems })
	local worldEsp = world:Box({ Name = "WORLD ESP", Column = 1, RowSpacing = 7, PadY = 6 })
	for _, name in { "Bomb", "Weapons", "Hostages", "Grenades" } do worldEsp:SubMenu({ Name = name, Build = worldPopup }) end
	worldEsp:Toggle({ Name = "Grenade Trajectory", Tip = false, Options = trajectory })
	worldEsp:Toggle({ Name = "Grenade Proximity Warnings" })
	local hud = world:Box({ Name = "HUD", Column = 2, RowSpacing = 7, PadY = 6 })
	hud:Combo({ Name = "Radar", Options = selectItems })
	hud:Combo({ Name = "Scope Overlay", Options = overlayItems })
	hud:Toggle({ Name = "Inaccuracy Overlay", Color = newColor(Color3.new(.62, .64, .7)) })
	for _, name in { "Death Notices", "Scoreboard", "Crosshairs" } do hud:SubMenu({ Name = name, Build = worldPopup }) end
	local miscWorld = world:Box({ Name = "MISCELLANEOUS", Column = 2, RowSpacing = 7, PadY = 6 })
	miscWorld:SubMenu({ Name = "Windows", Build = worldPopup })
	miscWorld:SubMenu({ Name = "Removals", Build = worldPopup })
	miscWorld:SubMenu({ Name = "Ambience", Tip = "Per-map lighting and weather.", Callback = openAmbience })
	for _, name in { "Hit Marker", "Bullet Tracers", "Bullet Impacts" } do miscWorld:SubMenu({ Name = name, Build = worldPopup }) end

	-- Shader: the controls are all here, but Roblox has no shaders to run them with.
	shader:Columns({ 0.42, 0.58 })
	local background = shader:Box({ Name = "BACKGROUND", Column = 1 })
	background:Toggle({ Name = "Enabled", Tip = "Draw the selected effect behind the menu's panels.", Options = function(f)
		f:Section({ Border = false }, function(s)
			s:Slider({ Name = "Opacity", Min = 0, Max = 100, Default = 35, Format = "%d%%" })
			s:Slider({ Name = "Speed", Min = 0, Max = 300, Default = 100, Format = "%d%%" })
		end)
	end })
	background:Toggle({ Name = "Blur On Shader", Tip = "Blur the selected effect behind the menu.", OptionsWidth = 240, Options = function(f)
		f:Section({ Border = false }, function(s) s:Slider({ Name = "Blur Intensity", Min = 0, Max = 30, Default = 8, Format = "%d px" }) end)
	end })
	local effect = shader:Box({ Name = "EFFECT", Column = 2, Height = 0, Scrollable = true, RowSpacing = 3, PadY = 6 })
	local effects = {
		{ "Plasma", "FIRE" }, { "Galaxy", "STAR" }, { "Liquid Ether", "WATER" }, { "Liquid Chrome", "TINT" }, { "Color Bends", "PALETTE" }, { "Light Rays", "SUN" },
		{ "Lightning", "BOLT" }, { "Line Waves", "WAVE_SQUARE" }, { "Particles", "ATOM" }, { "Pixel Snow", "SNOWFLAKE" }, { "Prism", "GEM" }, { "Prismatic Burst", "CERTIFICATE" },
		{ "Liquid Glass", "ADJUST" }, { "Mesh Gradient", "FILL_DRIP" }, { "Aurora", "MOUNTAIN" }, { "Dot Matrix", "TH" }, { "Hex Grid", "TH_LARGE" }, { "Starfield Warp", "ROCKET" },
		{ "Voronoi", "VECTOR_SQUARE" }, { "Rain on Glass", "CLOUD_RAIN" }, { "Click Ripple", "BULLSEYE" },
	}
	local effectRows, picked = {}, 1
	local function pickEffect(i)
		picked = i
		for k, row in effectRows do row:Select(k == picked) end
	end
	for i, item in effects do
		effectRows[i] = effect:Framed("[" .. item[2] .. "]" .. item[1], {
			Selected = i == 1,
			Callback = function() pickEffect(i) end,
		})
	end
	win:Flag("Shader/EFFECT/Selected", function() return picked end, function(v) if effectRows[v] then pickEffect(v) end end)

	local sampleOptions = { "First", "Second", "Third", "Fourth" }
	local inputs = components:Box({ Name = "INPUTS", Column = 1 })
	inputs:Toggle({ Name = "Enabled", Default = true })
	inputs:Keybind({ Name = "Keyboard shortcut", Default = Enum.KeyCode.LeftControl, ShowInList = false })
	inputs:Textbox({ Name = "Text field", Placeholder = "Type to test...", Default = "Sample text" })
	inputs:Combo({ Name = "Single choice", Options = sampleOptions, Default = 2, Searchable = true })
	inputs:Multi({ Name = "Multiple choices", Options = sampleOptions, Default = { true, false, true, false } })
	inputs:Slider({ Name = "Decimal slider", Min = 0, Max = 1, Default = 0.35, Decimals = 2 })
	inputs:RangeSlider({ Name = "Range slider", Min = 0, Max = 100, Default = { 20, 80 } })
	inputs:Stepper({ Name = "Stepper", Min = 0, Max = 20, Step = 2, Default = 6 })
	inputs:Segmented({ Name = "Segmented selector", Options = { "One", "Two", "Three" }, Default = 2 })
	inputs:Radio({ Name = "Radio selector", Options = sampleOptions, Default = 1, Layout = "Horizontal" })

	local edits = components:Box({ Name = "EDITORS", Column = 1 })
	edits:Color({ Name = "Color picker", Color = newColor(Color3.fromRGB(105, 92, 255)) })
	edits:CurveEditor({ Name = "Editable curve", Points = {
		Vector2.new(0, 0), Vector2.new(0.18, 0.08), Vector2.new(0.72, 0.86), Vector2.new(1, 1),
	} })

	local actions = components:Box({ Name = "ACTIONS AND ROWS", Column = 2 })
	actions:Button({ Name = "Run demo action", Tip = false })
	actions:Text({ Text = "Status, progress, and collapsible groups", Height = 22, Color = T.Soft })
	actions:Status({ Name = "Connection", Default = "Connected" })
	actions:Progress({ Name = "Progress", Min = 0, Max = 100, Default = 68 })
	actions:ButtonRow({ Name = "Centered left" }, { Name = "Centered right" })
	actions:Framed("A selectable framed row", { Selected = true })
	actions:Framed("Another framed row")
	actions:SubMenu({ Name = "Popup control showcase", Build = function(card)
		card:Section({ Border = true }, function(section)
			section:Row(nil, "Plain section row", function() end)
			section:Option("ADJUST", "Preview mode", sampleOptions, 2)
			section:PopupToggle("CHECK", "Popup toggle", true)
			section:Separator()
			section:Space(5)
			section:Slider({ Name = "Popup slider", Min = 0, Max = 100, Default = 50 })
		end)
	end })
	actions:Section({ Name = "Expandable section", Collapsible = true, DefaultOpen = false }, function(section)
		section:Toggle({ Name = "Child toggle", Default = true })
		section:Slider({ Name = "Child slider", Min = 0, Max = 100, Default = 45 })
	end)
	local tableRows = {}
	for i = 1, 50 do
		tableRows[i] = { Name = string.format("Item %02d", i), Type = i % 2 == 0 and "Even" or "Odd", Value = i * 7 }
	end
	actions:DataTable({
		Name = "Virtualized data table",
		Columns = { { Name = "Name", Width = 105 }, { Name = "Type", Width = 70 }, { Name = "Value" } },
		Data = tableRows, Height = 145, RowHeight = 24,
	})

	local curves = curveLab:Box({ Name = "CURVE PRESETS", Column = 1, RowSpacing = 6 })
	curves:CurveEditor({ Name = "Linear", Points = { Vector2.new(0, 0), Vector2.new(1, 1) } })
	curves:CurveEditor({ Name = "Ease in", Points = {
		Vector2.new(0, 0), Vector2.new(0.25, 0.08), Vector2.new(0.7, 0.52), Vector2.new(1, 1),
	} })
	curves:CurveEditor({ Name = "Local peak", Points = {
		Vector2.new(0, 0.1), Vector2.new(0.28, 0.82), Vector2.new(0.64, 0.35), Vector2.new(1, 0.92),
	} })
	local curveTools = curveLab:Box({ Name = "POINT EDITING", Column = 2 })
	curveTools:CurveEditor({ Name = "Add, move, or remove points", Points = {
		Vector2.new(0, 0), Vector2.new(0.3, 0.3), Vector2.new(0.7, 0.7), Vector2.new(1, 1),
	} })
	curveTools:Toggle({ Name = "The curve is a visual test", Default = true })

	local centered = typography:Box({ Name = "CENTERED CONTROLS", Column = 1 })
	centered:Button({ Name = "Centered button label", Tip = false })
	centered:ButtonRow({ Name = "Left action" }, { Name = "Right action" })
	centered:Keybind({ Name = "Centered key badge", Default = Enum.KeyCode.LeftShift, ShowInList = false })
	centered:Combo({ Name = "Centered value", Options = sampleOptions })

	local longText = typography:Box({ Name = "LONG LABELS AND CLIPPING", Column = 2 })
	longText:Toggle({ Name = "A deliberately long label to verify clipping at the column edge" })
	longText:Textbox({ Name = "A long text field label", Placeholder = "Placeholder text for width testing" })
	longText:Combo({ Name = "A long selection label", Options = {
		"A very long first option", "A very long second option", "A very long third option",
	} })
	longText:Color({ Name = "A long color-picker label", Color = newColor(Color3.fromRGB(80, 190, 160)) })
	longText:Framed("A long framed row label for truncation testing")

	win:Finish()
	win:RegisterAction("Open Components tab", function() win:selectTab(components) end)
	return win
end

function Library:Unload()
	sleepLoop()
	for job in Tickers do job.cancel() end
	while #Root.kids > 0 do
		Root.kids[#Root.kids]:destroy()
	end
	for _, connection in Connections do connection:Disconnect() end
	table.clear(Connections)
	Connected = false
	table.clear(Moving)
	table.clear(Queue)
	table.clear(Popups)
	table.clear(Windows)
	table.clear(Notes)
	table.clear(GlyphCache)
	table.clear(Shapes)
	table.clear(LazyRoots)
	table.clear(Widths)
	table.clear(WidthKeys)
	WidthCount, WidthCursor = 0, 1
	Hover, Held, Dragging = nil, nil, nil
	Tip.item, Tip.time, Tip.running = nil, 0, false
	TipAlpha = 0
	TipFrame, TipTitle, TipBody, TipOwner, TipCard = nil, nil, nil, nil, nil
	refreshKeybindHUD = nil
	CurrentWindow = nil
	for _, entry in RasterCache do
		if entry.raster.image then
			pcall(function() entry.raster.image:Destroy() end)
		end
	end
	table.clear(RasterCache)
	RasterCacheBytes, RasterUse = 0, 0
	if Screen then Screen:Destroy() end
	Screen, Stage, StageScale, Probe, NoteLayer = nil, nil, nil, nil, nil
end

-- Running the file again replaces the previous copy instead of stacking on top of it.
if type(_G) == "table" then
	if type(_G.NeverloseReloaded) == "table" and _G.NeverloseReloaded.Unload then
		pcall(_G.NeverloseReloaded.Unload, _G.NeverloseReloaded)
	end
	_G.NeverloseReloaded = Library
end

return Library
