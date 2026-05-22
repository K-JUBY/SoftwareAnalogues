package com.coursework.softwareanalogues.util;

import java.util.Map;
import java.util.ResourceBundle;

public final class TranslationUtils {
    private static final Map<String, String> CATEGORY_KEY_MAP = Map.ofEntries(
        Map.entry("Антивирусы", "category.antivirus"),
        Map.entry("Архиваторы", "category.archivers"),
        Map.entry("Браузеры", "category.browsers"),
        Map.entry("Графические редакторы", "category.graphics"),
        Map.entry("Среды разработки", "category.ide"),
        Map.entry("Офисные пакеты", "category.office"),
        Map.entry("Прочее", "category.other"),
        
        Map.entry("Antivirus", "category.antivirus"),
        Map.entry("Archivers", "category.archivers"),
        Map.entry("Browsers", "category.browsers"),
        Map.entry("Graphics", "category.graphics"),
        Map.entry("IDEs", "category.ide"),
        Map.entry("Office Suite", "category.office"),
        Map.entry("Other", "category.other"),
        
        Map.entry("Archivierungsprogramme", "category.archivers"),
        Map.entry("Browser", "category.browsers"),
        Map.entry("Grafikeditoren", "category.graphics"),
        Map.entry("Entwicklungsumgebungen", "category.ide"),
        Map.entry("Büropakete", "category.office"),
        Map.entry("Sonstiges", "category.other")
    );

    private TranslationUtils() {}

    public static String getLocalizedCategory(String dbCategoryName, ResourceBundle bundle) {
        if (dbCategoryName == null || dbCategoryName.isBlank()) {
            return "";
        }
        // Поиск ключа локализации в статической карте
        String key = CATEGORY_KEY_MAP.get(dbCategoryName.trim());
        if (key != null && bundle.containsKey(key)) {
            return bundle.getString(key);
        }
        // Возврат оригинального имени при отсутствии перевода
        return dbCategoryName;
    }
}
