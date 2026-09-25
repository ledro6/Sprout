package com.ledro6.sprout.app

/**
 * Приложение для Robolectric (находится само по имени): всё как в жизни,
 * кроме вопроса к сервисам Google Play для AR — их в Robolectric нет.
 */
class TestSproutApplication : SproutApplication() {
    override fun checkAr() = Unit
}
