package org.radargun.cachewrappers;

import com.hazelcast.config.Config;
import com.hazelcast.config.XmlConfigBuilder;
import com.hazelcast.core.BaseMap;
import com.hazelcast.core.Hazelcast;
import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.core.IMap;
import com.hazelcast.transaction.TransactionContext;
import org.radargun.CacheWrapper;
import org.radargun.features.AtomicOperationsCapable;
import org.radargun.logging.Log;
import org.radargun.logging.LogFactory;
import org.radargun.utils.TypedProperties;

import java.io.InputStream;

/**
 * An implementation of CacheWrapper that uses Hazelcast instance as an underlying implementation.
 */
public class Hazelcast3BaseWrapper implements CacheWrapper, AtomicOperationsCapable {

   private static final String DEFAULT_MAP_NAME = "default";

   private final Log log = LogFactory.getLog(getClass());
   private final boolean trace = log.isTraceEnabled();

   private HazelcastInstance hazelcastInstance;
   private IMap<Object, Object> hazelcastMap;
   private String mapName;

   private ThreadLocal<TransactionContext> transactionContext = new ThreadLocal<TransactionContext>();
   private ThreadLocal<BaseMap<Object, Object>> transactionMap = new ThreadLocal<BaseMap<Object, Object>>();

   /**
    * CacheWrapper
    */

   @Override
   public void setUp(String config, boolean isLocal, int nodeIndex, TypedProperties confAttributes) throws Exception {
      log.info("Creating cache with the following configuration: " + config);

      InputStream configStream = getAsInputStreamFromClassLoader(config);
      Config cfg = new XmlConfigBuilder(configStream).build();
      hazelcastInstance = Hazelcast.newHazelcastInstance(cfg);
      log.info("Hazelcast configuration:" + hazelcastInstance.getConfig().toString());

      mapName = getMapName(confAttributes);
      hazelcastMap = hazelcastInstance.getMap(mapName);
   }

   @Override
   public void tearDown() throws Exception {
      hazelcastInstance.getLifecycleService().shutdown();
      transactionContext.remove();
      transactionMap.remove();
   }

   @Override
   public boolean isRunning() {
      return hazelcastInstance.getLifecycleService().isRunning();
   }

   @Override
   public int getNumMembers() {
      if (trace) log.trace("Cluster size=" + hazelcastInstance.getCluster().getMembers().size());

      if (!hazelcastInstance.getLifecycleService().isRunning())
         return -1;
      else
         return hazelcastInstance.getCluster().getMembers().size();
   }

   @Override
   public String getInfo() {
      if (transactionContext.get() != null) {
         return "There are " + transactionMap.get().size() + " entries in the cache.";
      } else {
         return "There are " + hazelcastMap.size() + " entries in the cache.";
      }
   }

   @Override
   public boolean isTransactional(String bucket) {
      return true;
   }

   @Override
   public void startTransaction() {
      try {
         TransactionContext transaction = hazelcastInstance.newTransactionContext();
         transaction.beginTransaction();

         transactionMap.set(transaction.getMap(mapName));
         transactionContext.set(transaction);
      } catch (Exception e) {
         throw new RuntimeException(e);
      }
   }

   @Override
   public void endTransaction(boolean successful) {
      try {
         TransactionContext tc = transactionContext.get();
         if (successful) {
            tc.commitTransaction();
         } else {
            tc.rollbackTransaction();
         }
      } catch (Exception e) {
         throw new RuntimeException(e);
      } finally {
         transactionContext.remove();
         transactionMap.remove();
      }
   }

   @Override
   public int getLocalSize() {
      //not supported by Hazelcast, local size can be monitored through Hazelcast management center (web GUI)
      return -1;
   }

   @Override
   public int getTotalSize() {
      if (transactionContext.get() != null) {
         return transactionMap.get().size();
      } else {
         return hazelcastMap.size();
      }
   }

   /**
    * BasicOperations
    */

   @Override
   public void put(String bucket, Object key, Object value) throws Exception {
      if (trace) log.trace("PUT key=" + key);

      if (transactionContext.get() != null) {
         transactionMap.get().set(key, value);
      } else {
         hazelcastMap.set(key, value);
      }
   }

   @Override
   public Object get(String bucket, Object key) throws Exception {
      if (trace) log.trace("GET key=" + key);

      if (transactionContext.get() != null) {
         return transactionMap.get().get(key);
      } else {
         return hazelcastMap.get(key);
      }
   }

   @Override
   public Object getReplicatedData(String bucket, String key) throws Exception {
      return get(bucket, key);
   }

   @Override
   public Object remove(String bucket, Object key) throws Exception {
      if (trace) log.trace("REMOVE key=" + key);

      if (transactionContext.get() != null) {
         return transactionMap.get().remove(key);
      } else {
         return hazelcastMap.remove(key);
      }
   }

   @Override
   public void clear(boolean local) throws Exception {
      if (local) {
         log.warn("This cache cannot remove only local entries");
      }

      if (transactionContext.get() == null) {
         hazelcastMap.clear();
      }
   }

   /**
    * AtomicOperationsCapable
    */

   @Override
   public boolean replace(String bucket, Object key, Object oldValue, Object newValue) throws Exception {
      if (transactionContext.get() != null) {
         return transactionMap.get().replace(key, oldValue, newValue);
      } else {
         return hazelcastMap.replace(key, oldValue, newValue);
      }
   }

   @Override
   public Object putIfAbsent(String bucket, Object key, Object value) throws Exception {
      if (transactionContext.get() != null) {
         return transactionMap.get().putIfAbsent(key, value);
      } else {
         return hazelcastMap.putIfAbsent(key, value);
      }
   }

   @Override
   public boolean remove(String bucket, Object key, Object oldValue) throws Exception {
      if (transactionContext.get() != null) {
         return transactionMap.get().remove(key, oldValue);
      } else {
         return hazelcastMap.remove(key, oldValue);
      }
   }

   private InputStream getAsInputStreamFromClassLoader(String filename) {
      ClassLoader cl = Thread.currentThread().getContextClassLoader();
      InputStream is;
      try {
         is = cl == null ? null : cl.getResourceAsStream(filename);
      } catch (RuntimeException re) {
         // could be valid; see ISPN-827
         is = null;
      }
      if (is == null) {
         try {
            // check system class loader
            is = getClass().getClassLoader().getResourceAsStream(filename);
         } catch (RuntimeException re) {
            // could be valid; see ISPN-827
            is = null;
         }
      }
      return is;
   }

   private String getMapName(TypedProperties confAttributes) {
      return confAttributes.containsKey("map") ? confAttributes.getProperty("map") : DEFAULT_MAP_NAME;
   }
}
