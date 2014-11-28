package org.radargun.stages.cache.generators;

public class LongKeyGenerator implements KeyGenerator {
   @Override
   public Object generateKey(long keyIndex) {
      return keyIndex;
   }
}
