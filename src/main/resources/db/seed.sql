SET search_path TO software_app, public;

INSERT INTO categories(name, description)
VALUES
    ('Офисные пакеты', 'Программы для работы с документами'),
    ('Графические редакторы', 'Программы для обработки изображений'),
    ('Браузеры', 'Программы для просмотра веб-страниц'),
    ('Среды разработки', 'Инструменты для разработки программного обеспечения'),
    ('Антивирусы', 'Программы для защиты компьютера'),
    ('Архиваторы', 'Программы для работы с архивами')
ON CONFLICT DO NOTHING;

INSERT INTO developers(name, website)
VALUES
    ('Microsoft', 'https://www.microsoft.com'),
    ('The Document Foundation', 'https://www.documentfoundation.org'),
    ('Mozilla', 'https://www.mozilla.org'),
    ('Google', 'https://www.google.com'),
    ('Adobe', 'https://www.adobe.com'),
    ('The GIMP Team', 'https://www.gimp.org'),
    ('KDE', 'https://kde.org'),
    ('JetBrains', 'https://www.jetbrains.com'),
    ('Eclipse Foundation', 'https://www.eclipse.org'),
    ('Igor Pavlov', 'https://www.7-zip.org'),
    ('RARLAB', 'https://www.rarlab.com'),
    ('Kaspersky', 'https://www.kaspersky.ru'),
    ('Avast', 'https://www.avast.com')
ON CONFLICT DO NOTHING;

SELECT create_app_user('user', '123456', 'Пользователь')
WHERE NOT EXISTS (SELECT 1 FROM users WHERE lower(username) = 'user');

INSERT INTO software(title, description, system_requirements, size_mb, website, category_id, developer_id, is_free)
SELECT 'LibreOffice',
       'Свободный офисный пакет',
       'Windows/Linux/macOS, 2 GB RAM',
       350,
       'https://www.libreoffice.org',
       c.category_id,
       d.developer_id,
       TRUE
  FROM categories c, developers d
 WHERE c.name = 'Офисные пакеты'
   AND d.name = 'The Document Foundation'
   AND NOT EXISTS (SELECT 1 FROM software WHERE lower(title) = 'libreoffice');

INSERT INTO software(title, description, system_requirements, size_mb, website, category_id, developer_id, is_free)
SELECT item.title,
       item.description,
       item.system_requirements,
       item.size_mb,
       item.website,
       c.category_id,
       d.developer_id,
       item.is_free
  FROM (VALUES
        ('Microsoft Office', 'Коммерческий офисный пакет для документов, таблиц и презентаций', 'Windows/macOS, 4 GB RAM', 4500::numeric, 'https://www.microsoft.com/microsoft-365', 'Офисные пакеты', 'Microsoft', false),
        ('Google Docs', 'Веб-сервис для совместной работы с документами', 'Современный браузер, подключение к интернету', 0::numeric, 'https://docs.google.com', 'Офисные пакеты', 'Google', true),
        ('GIMP', 'Свободный графический редактор растровой графики', 'Windows/Linux/macOS, 2 GB RAM', 300::numeric, 'https://www.gimp.org', 'Графические редакторы', 'The GIMP Team', true),
        ('Adobe Photoshop', 'Профессиональный графический редактор', 'Windows/macOS, 8 GB RAM', 3500::numeric, 'https://www.adobe.com/products/photoshop.html', 'Графические редакторы', 'Adobe', false),
        ('Krita', 'Свободная программа для цифровой живописи и иллюстрации', 'Windows/Linux/macOS, 4 GB RAM', 250::numeric, 'https://krita.org', 'Графические редакторы', 'KDE', true),
        ('Mozilla Firefox', 'Свободный веб-браузер с поддержкой расширений', 'Windows/Linux/macOS, 2 GB RAM', 220::numeric, 'https://www.mozilla.org/firefox', 'Браузеры', 'Mozilla', true),
        ('Google Chrome', 'Популярный веб-браузер на базе Chromium', 'Windows/Linux/macOS, 2 GB RAM', 250::numeric, 'https://www.google.com/chrome', 'Браузеры', 'Google', true),
        ('Microsoft Edge', 'Браузер Microsoft на базе Chromium', 'Windows/macOS/Linux, 2 GB RAM', 240::numeric, 'https://www.microsoft.com/edge', 'Браузеры', 'Microsoft', true),
        ('Visual Studio Code', 'Легкий редактор кода с расширениями', 'Windows/Linux/macOS, 2 GB RAM', 350::numeric, 'https://code.visualstudio.com', 'Среды разработки', 'Microsoft', true),
        ('IntelliJ IDEA Community', 'Свободная IDE для Java и Kotlin', 'Windows/Linux/macOS, 8 GB RAM', 1500::numeric, 'https://www.jetbrains.com/idea', 'Среды разработки', 'JetBrains', true),
        ('Eclipse IDE', 'Расширяемая среда разработки', 'Windows/Linux/macOS, 4 GB RAM', 900::numeric, 'https://www.eclipse.org/ide', 'Среды разработки', 'Eclipse Foundation', true),
        ('7-Zip', 'Свободный архиватор с высокой степенью сжатия', 'Windows/Linux, 512 MB RAM', 20::numeric, 'https://www.7-zip.org', 'Архиваторы', 'Igor Pavlov', true),
        ('WinRAR', 'Коммерческий архиватор с поддержкой RAR и ZIP', 'Windows, 512 MB RAM', 10::numeric, 'https://www.rarlab.com', 'Архиваторы', 'RARLAB', false),
        ('Kaspersky Anti-Virus', 'Антивирусная защита для персональных компьютеров', 'Windows, 2 GB RAM', 1500::numeric, 'https://www.kaspersky.ru', 'Антивирусы', 'Kaspersky', false),
        ('Avast Free Antivirus', 'Бесплатный антивирус для базовой защиты', 'Windows/macOS, 2 GB RAM', 1200::numeric, 'https://www.avast.com', 'Антивирусы', 'Avast', true)
       ) AS item(title, description, system_requirements, size_mb, website, category_name, developer_name, is_free)
  JOIN categories c ON c.name = item.category_name
  JOIN developers d ON d.name = item.developer_name
 WHERE NOT EXISTS (SELECT 1 FROM software s WHERE lower(s.title) = lower(item.title));

INSERT INTO software_analogs(software_id, analog_id, reason, similarity_score)
SELECT source.software_id, target.software_id, item.reason, item.similarity_score
  FROM (VALUES
        ('LibreOffice', 'Microsoft Office', 'Оба продукта используются для работы с документами, таблицами и презентациями', 90),
        ('LibreOffice', 'Google Docs', 'Офисные документы и совместная работа', 78),
        ('GIMP', 'Adobe Photoshop', 'Редактирование растровых изображений', 82),
        ('GIMP', 'Krita', 'Свободные графические редакторы', 70),
        ('Mozilla Firefox', 'Google Chrome', 'Веб-браузеры общего назначения', 88),
        ('Google Chrome', 'Microsoft Edge', 'Браузеры на базе Chromium', 92),
        ('Visual Studio Code', 'IntelliJ IDEA Community', 'Инструменты для разработки программного обеспечения', 68),
        ('7-Zip', 'WinRAR', 'Архиваторы для сжатия и распаковки файлов', 85),
        ('Kaspersky Anti-Virus', 'Avast Free Antivirus', 'Антивирусные решения для защиты компьютера', 75)
       ) AS item(source_title, target_title, reason, similarity_score)
  JOIN software source ON source.title = item.source_title
  JOIN software target ON target.title = item.target_title
ON CONFLICT DO NOTHING;

INSERT INTO reviews(software_id, user_id, author_name, review_text, rating)
SELECT s.software_id, u.user_id, COALESCE(u.display_name, u.username), item.review_text, item.rating
  FROM (VALUES
        ('LibreOffice', 'Удобный свободный офисный пакет для учебы и дома.', 5),
        ('GIMP', 'Хорошая бесплатная альтернатива Photoshop для базовой обработки изображений.', 4),
        ('Mozilla Firefox', 'Гибкий браузер с большим количеством расширений.', 5),
        ('Visual Studio Code', 'Быстрый редактор кода, удобно расширяется плагинами.', 5),
        ('7-Zip', 'Простой и надежный архиватор.', 5)
       ) AS item(title, review_text, rating)
  JOIN software s ON s.title = item.title
  JOIN users u ON lower(u.username) = 'user'
 WHERE NOT EXISTS (
       SELECT 1 FROM reviews r
        WHERE r.software_id = s.software_id
          AND r.review_text = item.review_text
 );
