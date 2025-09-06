//
//  SafetyAnalysisSchema.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 06/09/2025.
//

import Foundation

enum SafetyAnalysisSchema {
    /// Gemini v1/v1beta response_schema format
    static func geminiResponseSchema() -> [String: Any] {
        return [
            "type": "OBJECT",
            "required": [
                "productName",
                "productType",
                "overallSafetyScore",
                "childSafetyScore",
                "dogSafetyScore",
                "catSafetyScore",
                "modelConfidence",
                "recognitionConfidence",
                "generalSafety",
                "petSafety",
                "hygieneWarnings",
                "recalls"
            ],
            "properties": [
                "productName": ["type": "STRING"],
                "productType": ["type": "STRING"],
                
                // Scoring fields
                "overallSafetyScore": ["type": "INTEGER"],
                "childSafetyScore":  ["type": "INTEGER"],
                "dogSafetyScore":    ["type": "INTEGER", "nullable": true],
                "catSafetyScore":    ["type": "INTEGER", "nullable": true],
                
                // Confidence
                "modelConfidence":       ["type": "NUMBER"],
                "recognitionConfidence": ["type": "NUMBER"],
                
                // General safety (pros/cons)
                "generalSafety": [
                    "type": "OBJECT",
                    "required": ["pros", "cons"],
                    "properties": [
                        "pros": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "required": ["label", "severity", "category"],
                                "properties": [
                                    "label":    ["type": "STRING"],
                                    "severity": ["type": "STRING", "enum": ["low","medium","high"]],
                                    "category": ["type": "STRING"]
                                ]
                            ]
                        ],
                        "cons": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "required": ["label", "severity", "category"],
                                "properties": [
                                    "label":    ["type": "STRING"],
                                    "severity": ["type": "STRING", "enum": ["low","medium","high"]],
                                    "category": ["type": "STRING"]
                                ]
                            ]
                        ]
                    ]
                ],
                
                // Pet safety (dogs/cats warnings)
                "petSafety": [
                    "type": "OBJECT",
                    "required": ["dogs", "cats"],
                    "properties": [
                        "dogs": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "required": ["severity", "warning", "reason"],
                                "properties": [
                                    "severity": ["type": "STRING", "enum": ["low","medium","high"]],
                                    "warning":  ["type": "STRING"],
                                    "reason":   ["type": "STRING"]
                                ]
                            ]
                        ],
                        "cats": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "required": ["severity", "warning", "reason"],
                                "properties": [
                                    "severity": ["type": "STRING", "enum": ["low","medium","high"]],
                                    "warning":  ["type": "STRING"],
                                    "reason":   ["type": "STRING"]
                                ]
                            ]
                        ]
                    ]
                ],
                
                // Hygiene warnings
                "hygieneWarnings": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "required": ["type", "message"],
                        "properties": [
                            "type":    ["type": "STRING"],
                            "message": ["type": "STRING"]
                        ]
                    ]
                ],
                
                // Recalls
                "recalls": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "required": ["date", "reason", "severity", "source"],
                        "properties": [
                            "date":    ["type": "STRING"],
                            "reason":  ["type": "STRING"],
                            "severity":["type": "STRING", "enum": ["low","medium","high"]],
                            "source":  ["type": "STRING"]
                        ]
                    ]
                ]
            ]
        ]
    }
}
