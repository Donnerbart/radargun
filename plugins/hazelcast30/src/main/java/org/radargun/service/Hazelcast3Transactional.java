package org.radargun.service;

import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.transaction.TransactionContext;
import org.radargun.logging.Log;
import org.radargun.logging.LogFactory;
import org.radargun.traits.Transactional;

/**
 * Provides transactional operations for Hazelcast
 *
 * @author Radim Vansa &lt;rvansa@redhat.com&gt;
 */
public class Hazelcast3Transactional implements Transactional {
   private static final String DEFAULT_CACHE_NAME = "transactional";
   private static final Log log = LogFactory.getLog(Hazelcast3Transactional.class);
   private static final boolean trace = log.isTraceEnabled();

   protected final HazelcastService service;

   public Hazelcast3Transactional(HazelcastService service) {
      this.service = service;
   }

   @Override
   public Configuration getConfiguration(String cache) {
      return (DEFAULT_CACHE_NAME.equals(cache)) ? Configuration.TRANSACTIONAL : Configuration.NON_TRANSACTIONAL;
   }

   @Override
   public Transaction getTransaction() {
      return new Tx();
   }

   private class Tx implements Transactional.Transaction {
      private final TransactionContext transactionContext;

      private boolean started = false;

      public Tx() {
         transactionContext = ((HazelcastInstance) service.hazelcastInstance).newTransactionContext();
      }

      @Override
      public <T> T wrap(T resource) {
         if (!started) {
            begin();
         }
         return (T) new Hazelcast3Operations.Cache(transactionContext.getMap(DEFAULT_CACHE_NAME));
      }

      @Override
      public void begin() {
         if (trace) log.trace("Starting TX " + transactionContext.getTxnId());
         if (!started) {
            transactionContext.beginTransaction();
            started = true;
         }
      }

      @Override
      public void commit() {
         if (trace) log.trace("Committing TX " + transactionContext.getTxnId());
         transactionContext.commitTransaction();
      }

      @Override
      public void rollback() {
         if (trace) log.trace("Rolling back TX " + transactionContext.getTxnId());
         transactionContext.rollbackTransaction();
      }
   }
}
