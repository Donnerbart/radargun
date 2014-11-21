package org.radargun.cachewrappers;

import org.gridgain.grid.Grid;
import org.gridgain.grid.GridException;
import org.gridgain.grid.GridGain;
import org.gridgain.grid.cache.GridCache;
import org.gridgain.grid.cache.GridCacheTx;
import org.radargun.CacheWrapper;
import org.radargun.features.AtomicOperationsCapable;
import org.radargun.logging.Log;
import org.radargun.logging.LogFactory;
import org.radargun.utils.TypedProperties;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/**
 * An implementation of CacheWrapper that uses Gridgain GridCache as an underlying implementation.
 */
public class GridgainWrapper implements CacheWrapper, AtomicOperationsCapable {

   protected final Log log = LogFactory.getLog(getClass());
   private final boolean trace = log.isTraceEnabled();

   private static final String DEFAULT_MAP_NAME = "themap";
   protected GridCache<Object, Object> cache;
   private Grid grid;

   @Override
   public void setUp(String config, boolean isLocal, int nodeIndex, TypedProperties confAttributes) throws Exception {
      log.info("Creating cache with the following configuration: " + config);
      InputStream in = getAsInputStreamFromClassLoader(config);

      File file = File.createTempFile("gridgain", "config");
      FileOutputStream out = new FileOutputStream(file);

      byte[] buffer = new byte[1024];
      int len;
      while ((len = in.read(buffer)) != -1) {
         out.write(buffer, 0, len);
      }
      out.close();

//      log.info("=====================================");
//      for (Object key : confAttributes.keySet()) {
//         log.info(key + " " + confAttributes.get(key));
//      }
//      log.info("=====================================");
//
//      final GridCacheConfiguration cfg = new GridCacheConfiguration();
//      cfg.setCacheMode(GridCacheMode.PARTITIONED);
//      cfg.setSwapEnabled(false);
//      //cfg.setAtomicityMode(GridCacheAtomicityMode.ATOMIC);
//      cfg.setAtomicityMode(GridCacheAtomicityMode.TRANSACTIONAL);
//      cfg.setQueryIndexEnabled(false);
//      cfg.setBackups(0);
//      cfg.setStartSize(1000000);
//      cfg.setName(DEFAULT_MAP_NAME);
//      final GridConfiguration gridConfiguration = new GridConfiguration();
//      gridConfiguration.setRestEnabled(false);
//      gridConfiguration.setMarshaller(new GridOptimizedMarshaller());
//      gridConfiguration.setCacheConfiguration(cfg);

      grid = GridGain.start(file.getAbsolutePath());
      cache = grid.cache(DEFAULT_MAP_NAME);
   }

   @Override
   public void tearDown() throws Exception {
      GridGain.stopAll(true);
   }

   @Override
   public boolean isRunning() {
      return GridGain.allGrids().contains(grid);
   }

   @Override
   public void put(String bucket, Object key, Object value) throws Exception {
      if (trace) log.trace("PUT key=" + key);
      cache.put(key, value);
   }

   @Override
   public Object get(String bucket, Object key) throws Exception {
      if (trace) log.trace("GET key=" + key);
      return cache.get(key);
   }

   @Override
   public Object remove(String bucket, Object key) throws Exception {
      if (trace) log.trace("REMOVE key=" + key);
      return cache.remove(key);
   }

   @Override
   public boolean replace(String bucket, Object key, Object oldValue, Object newValue) throws Exception {
      return cache.replace(key, oldValue, newValue);
   }

   @Override
   public Object putIfAbsent(String bucket, Object key, Object value) throws Exception {
      return cache.putIfAbsent(key, value);
   }

   @Override
   public boolean remove(String bucket, Object key, Object oldValue) throws Exception {
      return cache.remove(key, oldValue);
   }

   @Override
   public void clear(boolean local) throws Exception {
      if (local) {
         log.warn("This cache cannot remove only local entries");
      }
      cache.clearAll();
   }

   @Override
   public int getNumMembers() {
      try {
         return grid.nodes().size();
      } catch (RuntimeException e) {
         log.warn("failed to getNumMembers", e);
         return -1;
      }
   }

   @Override
   public String getInfo() {
      return "There are " + cache.size() + " entries in the cache.";
   }

   @Override
   public Object getReplicatedData(String bucket, String key) throws Exception {
      return get(bucket, key);
   }

   @Override
   public boolean isTransactional(String bucket) {
      return false;
   }

   private static final ThreadLocal<GridCacheTx> transactionThreadLocal = new ThreadLocal<GridCacheTx>() {
   };

   @Override
   public void startTransaction() {
      GridCacheTx tx = cache.txStart();
      transactionThreadLocal.set(tx);
   }

   @Override
   public void endTransaction(boolean successful) {
      GridCacheTx tx = transactionThreadLocal.get();
      if (tx != null) {
         try {
            if (successful) {
               tx.commit();
            } else {
               tx.rollback();
            }
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }
   }

   @Override
   public int getLocalSize() {
      return -1; //not supported by Hazelcast, local size can be monitored through Hazelcast management center (web GUI)
   }

   @Override
   public int getTotalSize() {
      return cache.size();
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
}
