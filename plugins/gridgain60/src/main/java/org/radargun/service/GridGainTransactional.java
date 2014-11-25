package org.radargun.service;

import org.gridgain.grid.GridException;
import org.gridgain.grid.cache.GridCache;
import org.gridgain.grid.cache.GridCacheTx;
import org.radargun.traits.Transactional;

/**
 * Provides transactional operations for GridGain
 */
public class GridGainTransactional implements Transactional {
   private static final String DEFAULT_CACHE_NAME = "transactional";

   protected final GridGainService service;

   public GridGainTransactional(GridGainService service) {
      this.service = service;
   }

   @Override
   public Configuration getConfiguration(String cacheName) {
      return (DEFAULT_CACHE_NAME.equals(cacheName)) ? Configuration.TRANSACTIONAL : Configuration.NON_TRANSACTIONAL;
   }

   @Override
   public Transaction getTransaction() {
      return new Tx();
   }

   protected class Tx implements Transaction {
      private final GridCache cache;
      private final GridGainOperations.Cache<?, ?> wrapper;

      private GridCacheTx tx;

      public Tx() {
         cache = service.grid.cache(DEFAULT_CACHE_NAME);
         wrapper = new GridGainOperations.Cache<Object, Object>(cache);
      }

      @Override
      public <T> T wrap(T resource) {
         return (T) wrapper;
      }

      @Override
      public void begin() {
         tx = cache.txStart();
      }

      @Override
      public void commit() {
         try {
            tx.commit();
         } catch (GridException e) {
            throw new RuntimeException(e);
         } finally {
            try {
               tx.close();
            } catch (GridException ignored) {
            }
         }
      }

      @Override
      public void rollback() {
         try {
            tx.rollback();
         } catch (GridException e) {
            throw new RuntimeException(e);
         } finally {
            try {
               tx.close();
            } catch (GridException ignored) {
            }
         }
      }
   }
}
