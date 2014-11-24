package org.radargun.service;

import org.radargun.Service;
import org.radargun.traits.CacheInformation;
import org.radargun.traits.ProvidesTrait;
import org.radargun.traits.Transactional;

/**
 * An implementation of CacheWrapper that uses Gridgain GridCache as an underlying implementation.
 */
@Service(doc = "GridGain")
public class GridGain62Service extends GridGainService {

   @ProvidesTrait
   @Override
   public Transactional createTransactional() {
      return new GridGainTransactional(this);
   }

   @ProvidesTrait
   @Override
   public CacheInformation createCacheInfo() {
      return new GridGainCacheInfo(this);
   }

   @ProvidesTrait
   @Override
   public GridGainOperations createOperations() {
      return new GridGainOperations(this);
   }
}
