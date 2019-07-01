Pod::Spec.new do |spec|
  spec.name          = 'APReorderableStackView'
  spec.version       = '1.0'
  spec.license       = { :type => 'MIT', :file => 'LICENSE' }
  spec.homepage      = 'https://github.com/clayellis/APReorderableStackView'
  spec.authors       = ['Clay Ellis']
  spec.summary       = 'A UIStackView with drag to reorder support'
  spec.source        = { :git => 'https://github.com/clayellis/APReorderableStackView.git', :tag => 'v1.0' }
  spec.source_files  = 'ReorderStackView/APRedorderableStackView.swift'
  spec.swift_version = '5.0'
  spec.platforms     = { "ios" => "9.0" }
end
