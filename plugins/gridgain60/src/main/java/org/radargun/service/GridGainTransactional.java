package org.radargun.service;

import org.gridgain.grid.GridException;
import org.radargun.traits.Transactional;

/**
 * Provides transactional operations for Hazelcast
 *
 * @author Radim Vansa &lt;rvansa@redhat.com&gt;
 */
public class GridGainTransactional implements Transactional {
   protected final GridGainService service;

   public GridGainTransactional(GridGainService service) {
      this.service = service;
   }

   @Override
   public Configuration getConfiguration(String cacheName) {
      return Configuration.TRANSACTIONS_ENABLED;
   }

   @Override
   public Transaction getTransaction() {
      return new Tx();
   }

   protected class Tx implements Transaction {
      private final org.gridgain.grid.cache.GridCacheTx tx;

      public Tx() {
         this.tx = service.cache.txStart();
      }

      @Override
      public <T> T wrap(T resource) {
         /*
         if (resource == null) {
            return null;
         } else if (resource instanceof GridGainOperations.Cache) {
            if (((GridGainOperations.Cache) resource).map.tx() != null) {
               return resource;
            }
         } else {
            throw new IllegalArgumentException(String.valueOf(resource));
         }
         */
         return resource;
      }

      @Override
      public void begin() {
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
