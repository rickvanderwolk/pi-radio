"""
Radio station management module.
Handles loading and merging of default and custom radio stations.
"""
import json
import os
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)


class StationManager:
    """Manages radio stations from default and custom configuration files."""

    def __init__(self, base_dir: Optional[str] = None):
        """
        Initialize the StationManager.

        Args:
            base_dir: Base directory where station files are located.
                     Defaults to the directory of this script.
        """
        if base_dir is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))

        self.base_dir = base_dir
        self.default_stations_file = os.path.join(base_dir, 'default_stations.json')
        self.custom_stations_file = os.path.join(base_dir, 'custom_stations.json')
        self._stations: Dict[str, str] = {}
        self._load_stations()

    def _load_json_file(self, filepath: str) -> Dict[str, any]:
        """
        Load a JSON file safely.

        Args:
            filepath: Path to the JSON file

        Returns:
            Dictionary with loaded data, or empty dict if file doesn't exist or is invalid
        """
        if not os.path.exists(filepath):
            logger.debug(f"File not found: {filepath}")
            return {}

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                logger.info(f"Loaded {len(data)} stations from {os.path.basename(filepath)}")
                return data
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in {filepath}: {e}")
            return {}
        except Exception as e:
            logger.error(f"Error loading {filepath}: {e}")
            return {}

    def _normalize_stations(self, stations_data: Dict) -> Dict[str, str]:
        """
        Normalize station data to simple key-url mapping.

        Supports both formats:
        - Simple: {"station_name": "url"}
        - Extended: {"station_name": {"url": "...", "display_name": "..."}}

        Args:
            stations_data: Raw station data from JSON

        Returns:
            Normalized dictionary with station_name: url mapping
        """
        normalized = {}

        for key, value in stations_data.items():
            if isinstance(value, str):
                # Simple format: direct URL
                normalized[key] = value
            elif isinstance(value, dict) and 'url' in value:
                # Extended format: extract URL
                normalized[key] = value['url']
            else:
                logger.warning(f"Invalid station format for '{key}': {value}")

        return normalized

    def _load_stations(self):
        """Load custom stations if available, otherwise fall back to default stations."""
        # Load custom stations first
        custom_data = self._load_json_file(self.custom_stations_file)
        custom_stations = self._normalize_stations(custom_data)

        # If custom stations exist, use only those
        if custom_stations:
            self._stations = custom_stations
            logger.info(f"Using custom stations only (default stations ignored)")
        else:
            # Fall back to default stations if no custom stations
            default_data = self._load_json_file(self.default_stations_file)
            default_stations = self._normalize_stations(default_data)
            self._stations = default_stations
            logger.info(f"No custom stations found, using default stations")

        logger.info(f"Total stations loaded: {len(self._stations)}")

        if not self._stations:
            logger.warning("No stations loaded! Check your station files.")

    def get_stations(self) -> Dict[str, str]:
        """
        Get all loaded stations.

        Returns:
            Dictionary mapping station names to URLs
        """
        return self._stations.copy()

    def get_station_names(self) -> list:
        """
        Get list of all station names.

        Returns:
            List of station name strings
        """
        return list(self._stations.keys())

    def get_station_url(self, station_name: str) -> Optional[str]:
        """
        Get URL for a specific station.

        Args:
            station_name: Name of the station

        Returns:
            Station URL or None if station not found
        """
        return self._stations.get(station_name)

    def is_valid_station(self, station_name: str) -> bool:
        """
        Check if a station name exists.

        Args:
            station_name: Name to check

        Returns:
            True if station exists, False otherwise
        """
        return station_name in self._stations

    def reload(self):
        """Reload stations from files."""
        logger.info("Reloading stations...")
        self._load_stations()
