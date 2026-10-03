<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ListTables extends Command
{
    protected $signature = 'db:tables';
    protected $description = 'List all tables in database';

    public function handle()
    {
        $tables = DB::select('SHOW TABLES');
        
        $this->info("Tables in Database:");
        foreach ($tables as $table) {
            $tableName = array_values((array) $table)[0];
            $this->line("- {$tableName}");
        }
        
        return 0;
    }
}