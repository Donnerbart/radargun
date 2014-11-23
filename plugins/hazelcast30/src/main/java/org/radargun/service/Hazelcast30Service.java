package org.radargun.service;

import com.sun.xml.internal.ws.util.VersionUtil;
import org.radargun.Service;
import org.radargun.traits.ProvidesTrait;
import org.radargun.traits.Queryable;
import org.radargun.traits.Transactional;

/**
 * An implementation of CacheWrapper that uses Hazelcast instance as an underlying implementation.
 * @author Maido Kaara
 */
@Service(doc = "Hazelcast")
public class Hazelcast30Service extends HazelcastService {
   @ProvidesTrait
   @Override
   public Transactional createTransactional() {
      return new Hazelcast3Transactional(this);
   }

   @ProvidesTrait
   @Override
   public HazelcastOperations createOperations() {
      return new Hazelcast3Operations(this);
   }

   @ProvidesTrait
   public Queryable createQueryable() {
      return new Hazelcast3Queryable(this);
   }
}
