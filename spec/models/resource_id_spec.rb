require 'spec_helper'
require 'routemaster/models/resource_id'

describe Routemaster::Models::ResourceID do
  shared_examples 'failure' do |title, value|
    it "rejects #{title} (#{value.inspect})" do
      expect { described_class.new(value) }.to raise_error(ArgumentError)
    end
  end

  shared_examples 'success' do |title, value|
    it "accepts #{title} (#{value.inspect})" do
      expect { described_class.new(value) }.not_to raise_error
    end

    it { expect(described_class.new(value)).to eq value }
  end

  it_behaves_like 'failure', 'random object', ['foo']
  it_behaves_like 'failure', 'negative integer', -1
  it_behaves_like 'failure', 'malformed UUID', 'b403625b-ABCD-4490-8bb6-2fedc1779d73'

  it_behaves_like 'success', 'integer', 42
  it_behaves_like 'success', 'UUID', '207e8939-0e61-4cf8-8aa2-abcf4a690d01'

end
