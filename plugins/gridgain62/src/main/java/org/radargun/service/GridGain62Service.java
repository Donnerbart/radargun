package org.radargun.service;

import org.gridgain.grid.Grid;
import org.gridgain.grid.GridException;
import org.gridgain.grid.GridGain;
import org.gridgain.grid.cache.GridCache;
import org.radargun.Service;
import org.radargun.config.Property;
import org.radargun.logging.Log;
import org.radargun.logging.LogFactory;
import org.radargun.traits.*;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * An implementation of CacheWrapper that uses Gridgain GridCache as an underlying implementation.
 */
@Service(doc = "GridGain")
public class GridGain62Service implements Lifecycle, Clustered {

   protected final Log log = LogFactory.getLog(getClass());

   protected Grid grid;
   protected GridCache<Object, Object> cache;

   @Property(name = "file", doc = "Configuration file.")
   private String config;

   @Property(name = "cache", doc = "Name of the map ~ cache", deprecatedName = "map")
   protected String mapName = "default";

   @ProvidesTrait
   public GridGain62Service getSelf() {
      return this;
   }

   @ProvidesTrait
   public Transactional createTransactional() {
      return new GridGainTransactional(this);
   }

   @ProvidesTrait
   public CacheInformation createCacheInfo() {
      return new GridGainCacheInfo(this);
   }

   @ProvidesTrait
   public GridGainOperations createOperations() {
      return new GridGainOperations(this);
   }

   @Override
   public void start() {
      log.info("Creating cache with the following configuration: " + config);
      InputStream in = getAsInputStreamFromClassLoader(config);

      try {
         File file = File.createTempFile("gridgain", "config");

         FileOutputStream out = new FileOutputStream(file);

         byte[] buffer = new byte[1024];
         int len;
         while ((len = in.read(buffer)) != -1) {
            out.write(buffer, 0, len);
         }
         out.close();

         grid = GridGain.start(file.getAbsolutePath());
         cache = grid.cache(mapName);

      } catch (IOException | GridException e) {
         throw new RuntimeException(e);
      }
   }

   @Override
   public void stop() {
      GridGain.stopAll(true);
   }

   @Override
   public boolean isRunning() {
      return GridGain.allGrids().contains(grid);
   }

   @Override
   public boolean isCoordinator() {
      return false;
   }

   @Override
   public int getClusteredNodes() {
      try {
         return grid.nodes().size();
      } catch (RuntimeException e) {
         log.warn("failed to getNumMembers", e);
         return -1;
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
}
