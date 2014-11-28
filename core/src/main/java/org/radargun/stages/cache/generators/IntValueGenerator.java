package org.radargun.stages.cache.generators;

import org.radargun.config.Init;
import org.radargun.config.Property;
import org.radargun.config.PropertyHelper;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.Random;

/**
 * Generates integers
 */
public class IntValueGenerator implements ValueGenerator {
   @Init
   public void init() {
   }

   @Override
   public Object generateValue(Object key, int size, Random random) {
      return random.nextInt();
   }

   @Override
   public int sizeOf(Object value) {
      return -1;
   }

   @Override
   public boolean checkValue(Object value, Object key, int expectedSize) {
      return true;
   }

   @Override
   public String toString() {
      return PropertyHelper.getDefinitionElementName(getClass()) + PropertyHelper.toString(this);
   }
}
