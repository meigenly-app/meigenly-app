package br.meigenly.core.di

import android.content.Context
import androidx.room.Room
import br.meigenly.data.db.AppDatabase
import br.meigenly.data.db.dao.CharacterDao
import br.meigenly.data.db.dao.FavoriteDao
import br.meigenly.data.db.dao.HistoryDao
import br.meigenly.data.db.dao.QuoteDao
import br.meigenly.data.db.dao.SeedStateDao
import br.meigenly.data.db.dao.WorkDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Singleton
    @Provides
    fun providesDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, AppDatabase.NAME)
            // Dev-stage only (TODO E9): destructive fallback while no public build exists;
            // replace by a real Migration when v1 is published.
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun providesWorkDao(db: AppDatabase): WorkDao = db.workDao()

    @Provides
    fun providesCharacterDao(db: AppDatabase): CharacterDao = db.characterDao()

    @Provides
    fun providesQuoteDao(db: AppDatabase): QuoteDao = db.quoteDao()

    @Provides
    fun providesSeedStateDao(db: AppDatabase): SeedStateDao = db.seedStateDao()

    @Provides
    fun providesFavoriteDao(db: AppDatabase): FavoriteDao = db.favoriteDao()

    @Provides
    fun providesHistoryDao(db: AppDatabase): HistoryDao = db.historyDao()
}
