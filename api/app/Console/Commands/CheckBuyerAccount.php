<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;

class CheckBuyerAccount extends Command
{
    protected $signature = 'user:check {email}';
    protected $description = 'Check user account details';

    public function handle()
    {
        $email = $this->argument('email');
        $user = User::where('email', $email)->first();
        
        if (!$user) {
            $this->error("User not found: {$email}");
            return 1;
        }
        
        $this->info("User Details:");
        $this->line("Name: {$user->name}");
        $this->line("Email: {$user->email}");
        $this->line("Role: {$user->role}");
        $this->line("Approval Status: {$user->approval_status}");
        $this->line("Created: {$user->created_at}");
        
        return 0;
    }
}
