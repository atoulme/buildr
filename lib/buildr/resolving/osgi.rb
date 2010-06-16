# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr
  
  class OSGiResolver < Buildr::Resolver
    def initialize()
      super(:osgi)
    end
    
    def resolve #TODO
      # Here we need to plug the Buildr4OSGi logic.
      artifacts << ["com.example:foo:jar:1.1", "com.example:bar:jar:1.1"]
      artifacts.flatten!
    end
    
    class << self
      def apply?(project)
        File.exist? project.path_to "META-INF/MANIFEST.MF"
      end
    end
  end
  
end