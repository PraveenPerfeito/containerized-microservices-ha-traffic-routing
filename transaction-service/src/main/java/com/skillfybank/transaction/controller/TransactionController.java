package com.skillfybank.transaction.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/transactions")
public class TransactionController {

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> status = new HashMap<>();
        status.put("status", "healthy");
        status.put("service", "transaction-service");
        return ResponseEntity.ok(status);
    }

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getTransactions() {
        List<Map<String, Object>> transactions = new ArrayList<>();
        Map<String, Object> t1 = new HashMap<>();
        t1.put("id", 1);
        t1.put("from", 1);
        t1.put("to", 2);
        t1.put("amount", 500);
        t1.put("status", "COMPLETED");
        transactions.add(t1);
        Map<String, Object> t2 = new HashMap<>();
        t2.put("id", 2);
        t2.put("from", 2);
        t2.put("to", 1);
        t2.put("amount", 200);
        t2.put("status", "COMPLETED");
        transactions.add(t2);
        return ResponseEntity.ok(transactions);
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createTransaction(@RequestBody Map<String, Object> body) {
        body.put("id", System.currentTimeMillis());
        body.put("status", "SUCCESS");
        return ResponseEntity.status(201).body(body);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getTransaction(@PathVariable Long id) {
        Map<String, Object> transaction = new HashMap<>();
        transaction.put("id", id);
        transaction.put("from", 1);
        transaction.put("to", 2);
        transaction.put("amount", 500);
        transaction.put("status", "COMPLETED");
        return ResponseEntity.ok(transaction);
    }
}
