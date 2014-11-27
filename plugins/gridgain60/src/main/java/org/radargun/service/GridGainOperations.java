package org.radargun.service;

import org.gridgain.grid.GridException;
import org.gridgain.grid.cache.GridCache;
import org.radargun.traits.BasicOperations;
import org.radargun.traits.ConditionalOperations;

public class GridGainOperations implements BasicOperations, ConditionalOperations {
   protected final GridGainService service;

   public GridGainOperations(GridGainService service) {
      this.service = service;
   }

   @Override
   public <K, V> GridGainCache<K, V> getCache(String cacheName) {
      if (cacheName == null)
      {
         cacheName = service.mapName;
      }
      return new Cache<>(service.grid.<K, V>cache(cacheName));
   }

   protected interface GridGainCache<K, V> extends BasicOperations.Cache<K, V>, ConditionalOperations.Cache<K, V> {
   }

   protected static class Cache<K, V> implements GridGainCache<K, V> {
      protected final GridCache<K, V> map;

      public Cache(GridCache<K, V> map) {
         this.map = map;
      }

      @Override
      public V get(K key) {
         try {
            return map.get(key);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public boolean containsKey(K key) {
         return map.containsKey(key);
      }

      @Override
      public void put(K key, V value) {
         try {
            map.putx(key, value);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public V getAndPut(K key, V value) {
         try {
            return map.put(key, value);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public boolean remove(K key) {
         try {
            return map.remove(key) != null;
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public V getAndRemove(K key) {
         try {
            return map.remove(key);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public boolean replace(K key, V value) {
         try {
            return map.replace(key, value) != null;
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public V getAndReplace(K key, V value) {
         try {
            return map.replace(key, value);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public void clear() {
         map.clearAll();
      }

      @Override
      public boolean putIfAbsent(K key, V value) {
         try {
            return map.putIfAbsent(key, value) == null;
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public boolean remove(K key, V oldValue) {
         try {
            return map.remove(key, oldValue);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }

      @Override
      public boolean replace(K key, V oldValue, V newValue) {
         try {
            return map.replace(key, oldValue, newValue);
         } catch (GridException e) {
            throw new RuntimeException(e);
         }
      }
   }
}
