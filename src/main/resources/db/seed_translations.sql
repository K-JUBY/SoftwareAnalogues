-- Переводы категорий на английский
SET search_path TO software_app, public;

INSERT INTO category_translations(category_id, locale, name, description)
SELECT c.category_id, 'en', t.name_en, t.description_en
  FROM categories c
  JOIN (VALUES
        ('Офисные пакеты', 'Office Suites', 'Software for working with documents'),
        ('Графические редакторы', 'Graphics Editors', 'Image processing software'),
        ('Браузеры', 'Browsers', 'Web browsing software'),
        ('Среды разработки', 'Development Environments', 'Software development tools'),
        ('Антивирусы', 'Antiviruses', 'Computer security software'),
        ('Архиваторы', 'Archivers', 'Archive management software')
       ) AS t(name_ru, name_en, description_en)
    ON c.name = t.name_ru
ON CONFLICT (category_id, locale) DO UPDATE
   SET name = EXCLUDED.name,
       description = EXCLUDED.description;
