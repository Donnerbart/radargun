package org.radargun.service;

import org.gridgain.grid.Grid;
import org.gridgain.grid.GridGain;
import org.gridgain.grid.cache.GridCache;
import org.radargun.traits.CacheInformation;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;

public class GridGainCacheInfo implements CacheInformation {
   protected final GridGain62Service service;

   public GridGainCacheInfo(GridGain62Service service) {
      this.service = service;
   }

   @Override
   public String getDefaultCacheName() {
      return service.mapName;
   }

   @Override
   public Collection<String> getCacheNames() {
      ArrayList<String> names = new ArrayList<String>();
      for (Grid grid : GridGain.allGrids()) {
         for (GridCache cache : grid.caches()) {
            names.add(cache.name());
         }
      }
      return names;
   }

   @Override
   public Cache getCache(String cacheName) {
      return new Cache(service.grid.cache(cacheName));
   }

   protected class Cache implements CacheInformation.Cache {
      protected final GridCache map;

      public Cache(GridCache map) {
         this.map = map;
      }

      @Override
      public long getOwnedSize() {
         return map.primarySize();
      }

      @Override
      public long getLocallyStoredSize() {
         return getMemoryStoredSize();
      }

      @Override
      public long getMemoryStoredSize() {
         return map.nearSize();
      }

      @Override
      public long getTotalSize() {
         return map.size();
      }

      @Override
      public Map<?, Long> getStructuredSize() {
         return Collections.singletonMap(map.name(), getOwnedSize());
      }

      @Override
      public int getNumReplicas() {
         return map.configuration().getBackups();
      }

      @Override
      public int getEntryOverhead() {
         return -1;
      }
   }
}
