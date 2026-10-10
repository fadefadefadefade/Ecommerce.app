<?php

namespace App\Http\Controllers\Api\Logistics;

use App\Http\Controllers\Controller;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function contacts(Request $request)
    {
        $me = $request->user()->id;

        $unread = Message::where('receiver_id', $me)->where('is_read', false)
            ->selectRaw('sender_id, count(*) as total')
            ->groupBy('sender_id')
            ->pluck('total', 'sender_id');

        $contacts = User::where('id', '!=', $me)
            ->when($request->search, fn ($q) => $q->where('name', 'like', "%{$request->search}%"))
            ->orderBy('name')
            ->get(['id', 'name', 'role'])
            ->map(fn ($u) => [
                'id'     => $u->id,
                'name'   => $u->name,
                'role'   => $u->role,
                'unread' => (int) ($unread[$u->id] ?? 0),
            ]);

        return response()->json(['contacts' => $contacts]);
    }

    /** Conversation with one contact; marks their messages as read. Pass after_id to poll for new ones. */
    public function messages(Request $request, User $contact)
    {
        $request->validate(['after_id' => 'nullable|integer']);
        $me = $request->user()->id;

        $messages = Message::where(function ($q) use ($me, $contact) {
                $q->where('sender_id', $me)->where('receiver_id', $contact->id);
            })
            ->orWhere(function ($q) use ($me, $contact) {
                $q->where('sender_id', $contact->id)->where('receiver_id', $me);
            })
            ->when($request->after_id, fn ($q) => $q->where('id', '>', $request->after_id))
            ->oldest('id')
            ->get(['id', 'sender_id', 'receiver_id', 'body', 'is_read', 'created_at']);

        Message::where('sender_id', $contact->id)
            ->where('receiver_id', $me)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json([
            'contact'  => ['id' => $contact->id, 'name' => $contact->name, 'role' => $contact->role],
            'messages' => $messages,
        ]);
    }

    public function send(Request $request)
    {
        $request->validate([
            'receiver_id' => 'required|exists:users,id',
            'body'        => 'required|string|max:2000',
        ]);

        $message = Message::create([
            'sender_id'   => $request->user()->id,
            'receiver_id' => $request->receiver_id,
            'body'        => $request->body,
        ]);

        return response()->json(['message' => $message->only(['id', 'sender_id', 'receiver_id', 'body', 'is_read', 'created_at'])], 201);
    }
}
