This is a simple coding agent implemented in Ruby, as an experiment accompanying my blog post: ["Coding agent in 94 lines of Ruby"](https://radanskoric.com/articles/coding-agent-in-ruby).

# Usage

Whatever method you use, first copy the `.env.example` file to `.env` and add your Anthropic API key. If you want to use a different provider, modify the `run.rb` file and set the key for the other provider. Check [RubyLLM configuration documentation](https://rubyllm.com/configuration) for details.

## Model Context Protocol (MCP) Support

This agent now supports [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) which allows you to add external tools. To use MCP tools, configure the `mcp.json` file in the root directory:

```json
{
  "mcpServers": {
    "serverName": {
      "command": "command-to-run-mcp-server",
      "args": ["arg1", "arg2"]
    }
  }
}
```

For example, to use the Playwright MCP server (included by default):

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

You can also use an SSE-based MCP server by specifying a URL:

```json
{
  "mcpServers": {
    "webMCP": {
      "url": "http://localhost:9292/mcp/sse"
    }
  }
}
```

To check if your MCP configuration is working, run:

```bash
ruby check_mcp.rb
```

## With docker

If you have docker the usage is really simple. Just run the `run_in_docker.sh` script.

The directory from which you run the script will be mounted into the container as `/workspace` and will be the directory in which the coding agent will operate.

## Without docker

If you're running it without docker you'll need Ruby and bundler installed.

Navigate to the root of the directory, run `bundle install`.

After that, call `ruby /path/to/run.rb` from the directory you want to operate on.

# Running tests

Execute `test/run_all.sh` from the root of the project.



