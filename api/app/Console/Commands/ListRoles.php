<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ListRoles extends Command
{
    protected $signature = 'roles:list';
    protected $description = 'List all distinct user roles';

    public function handle()
    {
        $roles = DB::table('users')->select('role')->distinct()->pluck('role');
        
        $this->info("User Roles in Database:");
        foreach ($roles as $role) {
            $count = DB::table('users')->where('role', $role)->count();
            $this->line("- {$role} ({$count} users)");
        }
        
        return 0;
    }
}
