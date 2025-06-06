# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

# rubocop:disable Metrics/BlockLength
RSpec.describe Tools::ListFiles do
  let(:tool) { described_class.new }

  describe '#execute' do
    context 'when no path is provided' do
      it 'lists files in the current directory' do
        result = tool.execute
        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end
    end

    context 'when path does not exist' do
      it 'returns an error hash' do
        result = tool.execute(path: '/nonexistent/path')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq('Path does not exist')
      end
    end

    context 'with empty directory' do
      let(:temp_dir) { Dir.mktmpdir }

      after { FileUtils.rm_rf(temp_dir) }

      it 'returns an empty array' do
        result = tool.execute(path: temp_dir)

        expect(result).to be_an(Array)
        expect(result).to be_empty
      end
    end

    context 'with valid directory structure' do
      let(:temp_dir) { Dir.mktmpdir }

      before do
        FileUtils.mkdir_p(File.join(temp_dir, 'subdir1'))
        FileUtils.mkdir_p(File.join(temp_dir, 'subdir2', 'nested'))
        FileUtils.touch(File.join(temp_dir, 'file1.txt'))
        FileUtils.touch(File.join(temp_dir, 'file2.rb'))
        FileUtils.touch(File.join(temp_dir, 'subdir1', 'nested_file.txt'))
        FileUtils.touch(File.join(temp_dir, 'subdir2', 'nested', 'deep_file.rb'))
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'lists all files and directories recursively' do
        result = tool.execute(path: temp_dir)

        expect(result).to be_an(Array)
        expect(result).to include(File.join(temp_dir, 'file1.txt'))
        expect(result).to include(File.join(temp_dir, 'file2.rb'))
        expect(result).to include("#{File.join(temp_dir, 'subdir1')}/")
        expect(result).to include("#{File.join(temp_dir, 'subdir2')}/")
        expect(result).to include(File.join(temp_dir, 'subdir1', 'nested_file.txt'))
        expect(result).to include("#{File.join(temp_dir, 'subdir2', 'nested')}/")
        expect(result).to include(File.join(temp_dir, 'subdir2', 'nested', 'deep_file.rb'))
      end

      it 'marks directories with trailing slash' do
        result = tool.execute(path: temp_dir)

        directories = result.select { |item| item.end_with?('/') }
        files = result.reject { |item| item.end_with?('/') }

        expect(directories).to include("#{File.join(temp_dir, 'subdir1')}/")
        expect(directories).to include("#{File.join(temp_dir, 'subdir2')}/")
        expect(files).to include(File.join(temp_dir, 'file1.txt'))
        expect(files).to include(File.join(temp_dir, 'file2.rb'))
      end
    end

    context 'when max_depth is specified' do
      let(:temp_dir) { Dir.mktmpdir }

      before do
        FileUtils.mkdir_p(File.join(temp_dir, 'level1', 'level2', 'level3'))
        FileUtils.touch(File.join(temp_dir, 'root_file.txt'))
        FileUtils.touch(File.join(temp_dir, 'level1', 'level1_file.txt'))
        FileUtils.touch(File.join(temp_dir, 'level1', 'level2', 'level2_file.txt'))
        FileUtils.touch(File.join(temp_dir, 'level1', 'level2', 'level3', 'level3_file.txt'))
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'respects max_depth parameter' do
        result = tool.execute(path: temp_dir, max_depth: 1)

        expect(result).to include(File.join(temp_dir, 'root_file.txt'))
        expect(result).to include("#{File.join(temp_dir, 'level1')}/")
        expect(result).to include(File.join(temp_dir, 'level1', 'level1_file.txt'))
        expect(result).not_to include(File.join(temp_dir, 'level1', 'level2', 'level2_file.txt'))
        expect(result).not_to include(File.join(temp_dir, 'level1', 'level2', 'level3', 'level3_file.txt'))
      end

      it 'works with max_depth of 0' do
        result = tool.execute(path: temp_dir, max_depth: 0)

        expect(result).to include(File.join(temp_dir, 'root_file.txt'))
        expect(result).to include("#{File.join(temp_dir, 'level1')}/")
        expect(result).not_to include(File.join(temp_dir, 'level1', 'level1_file.txt'))
      end

      it 'accepts max_depth as a string' do
        result = tool.execute(path: temp_dir, max_depth: '1')

        expect(result).to include(File.join(temp_dir, 'root_file.txt'))
        expect(result).to include("#{File.join(temp_dir, 'level1')}/")
        expect(result).to include(File.join(temp_dir, 'level1', 'level1_file.txt'))
        expect(result).not_to include(File.join(temp_dir, 'level1', 'level2', 'level2_file.txt'))
        expect(result).not_to include(File.join(temp_dir, 'level1', 'level2', 'level3', 'level3_file.txt'))
      end

      it 'returns error for invalid string max_depth' do
        result = tool.execute(path: temp_dir, max_depth: 'invalid')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq('Invalid max_depth: must be a non-negative integer')
      end

      it 'returns error for negative max_depth' do
        result = tool.execute(path: temp_dir, max_depth: -1)

        expect(result).to be_a(Hash)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq('Invalid max_depth: must be a non-negative integer')
      end

      it 'returns error for negative string max_depth' do
        result = tool.execute(path: temp_dir, max_depth: '-1')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq('Invalid max_depth: must be a non-negative integer')
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:glob).and_raise(StandardError, 'Test error')
      end

      it 'returns an error hash with the exception message' do
        result = tool.execute(path: '.')

        expect(result).to be_a(Hash)
        expect(result).to have_key(:error)
        expect(result[:error]).to eq('Test error')
      end
    end

    context 'with relative path' do
      let(:temp_dir) { Dir.mktmpdir }
      let(:relative_path) { File.basename(temp_dir) }

      before do
        FileUtils.touch(File.join(temp_dir, 'test_file.txt'))
        Dir.chdir(File.dirname(temp_dir))
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'handles relative paths correctly' do
        result = tool.execute(path: relative_path)

        expect(result).to be_an(Array)
        expect(result.any? { |path| path.end_with?('test_file.txt') }).to be true
      end
    end
  end

  describe 'tool metadata' do
    it 'has the correct description' do
      expected_description = 'Recursively list files and directories at a given path. ' \
                             'If no path is provided, lists files in the current directory.'
      expect(described_class.description).to eq(expected_description)
    end

    it 'can be instantiated' do
      expect(tool).to be_a(described_class)
      expect(tool).to respond_to(:execute)
    end
  end
end
# rubocop:enable Metrics/BlockLength
