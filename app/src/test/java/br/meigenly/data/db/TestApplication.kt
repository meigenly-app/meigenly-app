package br.meigenly.data.db

import android.app.Application

/**
 * Plain Application used by Robolectric tests so MeigenlyApp's startup seed-install
 * coroutine never runs inside tests (it would otherwise race the test's own installer).
 */
class TestApplication : Application()
